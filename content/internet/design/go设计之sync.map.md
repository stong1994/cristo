+++

date = 2022-10-31T11:00:00+08:00
title = "go设计之sync.Map"
url = "/internet/go/syncmap"

toc = true

+++



## 前瞻

go语言中内置的map类型不允许并发读写，否则会直接退出程序（不是panic）。于是，当我们有并发读写的需求时，往往通过加锁（`map+sync.Mutex/sync.RWMutex`）的方式来实现，而锁的使用会降低并发性能，因此go中内置了sync.Map实现了无锁的读写操作（部分场景下）。

然而，这种lock-free的实现必然存在着一定的限制——当我们得到某些东西的时候，往往就需要放弃另外一些东西。因此，必须了解其适用的场景才能使用sync.Map。

##  源码

源码位于`src/sync/map.go`.

### 基础结构Map

```go
type Map struct {
	mu Mutex

	// read contains the portion of the map's contents that are safe for
	// concurrent access (with or without mu held).
	//
	// The read field itself is always safe to load, but must only be stored with
	// mu held.
	//
	// Entries stored in read may be updated concurrently without mu, but updating
	// a previously-expunged entry requires that the entry be copied to the dirty
	// map and unexpunged with mu held.
	read atomic.Value // readOnly

	// dirty contains the portion of the map's contents that require mu to be
	// held. To ensure that the dirty map can be promoted to the read map quickly,
	// it also includes all of the non-expunged entries in the read map.
	//
	// Expunged entries are not stored in the dirty map. An expunged entry in the
	// clean map must be unexpunged and added to the dirty map before a new value
	// can be stored to it.
	//
	// If the dirty map is nil, the next write to the map will initialize it by
	// making a shallow copy of the clean map, omitting stale entries.
	dirty map[any]*entry

	// misses counts the number of loads since the read map was last updated that
	// needed to lock mu to determine whether the key was present.
	//
	// Once enough misses have occurred to cover the cost of copying the dirty
	// map, the dirty map will be promoted to the read map (in the unamended
	// state) and the next store to the map will make a new dirty copy.
	misses int
}
```

Map非常简洁，只有四个字段：

- mu: 一个互斥锁。既然sync.Map是在并发场景下应用的，因此锁的存在是能够预料到的，后续看下sync.Map中是如何使用的。
- read: 一个原子值，sync.Map的“无锁的读”就是读取该字段。
- dirty: 一个map，用来存储需要加锁才能访问的数据。dirty中存储read中不存在或者已经被抹除的数据。
- misses: 用来计算没有在read中获取到数据的次数，sync.Map会根据misses的大小来决定是否将dirty“更新”到read。

dirty中使用了entry类型的数据作为map中的值，我们看下:

```
type entry struct {
	// p points to the interface{} value stored for the entry.
	//
	// If p == nil, the entry has been deleted, and either m.dirty == nil or
	// m.dirty[key] is e.
	//
	// If p == expunged, the entry has been deleted, m.dirty != nil, and the entry
	// is missing from m.dirty.
	//
	// Otherwise, the entry is valid and recorded in m.read.m[key] and, if m.dirty
	// != nil, in m.dirty[key].
	//
	// An entry can be deleted by atomic replacement with nil: when m.dirty is
	// next created, it will atomically replace nil with expunged and leave
	// m.dirty[key] unset.
	//
	// An entry's associated value can be updated by atomic replacement, provided
	// p != expunged. If p == expunged, an entry's associated value can be updated
	// only after first setting m.dirty[key] = e so that lookups using the dirty
	// map find the entry.
	p unsafe.Pointer // *interface{}
}
```

可以看到entry就是存储数据指针p的结构。通过注释，我们了解到：

1. 如果p指针为空，说明entry被删除了，并且要么dirty为空，要么dirty[key]为空。

2. 如果p指针是expunged，说明entry被删除了，并且dirty不为空，dirty中的该entry不存在了。expunged数据如下，是一个“全局”的变量，用来表示该数据被抹除了。

   ```go
   var expunged = unsafe.Pointer(new(any))
   ```

### 读操作-Load

```go
// Load returns the value stored in the map for a key, or nil if no
// value is present.
// The ok result indicates whether value was found in the map.
func (m *Map) Load(key any) (value any, ok bool) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	if !ok && read.amended {
		m.mu.Lock()
		// Avoid reporting a spurious miss if m.dirty got promoted while we were
		// blocked on m.mu. (If further loads of the same key will not miss, it's
		// not worth copying the dirty map for this key.)
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			e, ok = m.dirty[key]
			// Regardless of whether the entry was present, record a miss: this key
			// will take the slow path until the dirty map is promoted to the read
			// map.
			m.missLocked()
		}
		m.mu.Unlock()
	}
	if !ok {
		return nil, false
	}
	return e.load()
}
```

1. 读取数据时，sync.Map会先在read中读取，该操作是不需要加锁的。
2. 如果在read中没有读取到并且dirty中存在read中不存在的数据，则会加锁，再次读取read。再次读取是因为：如果直接读取dirty，那么有可能在读取read和dirty中间dirty中的数据被提升到read，这样就会在dirty中读不到数据，这是单例模式常用的方式。
3. 若仍在read中读不到数据，并且dirty中存在read中不存在的数据，那么就读取dirty，并且进行`missLocked`

通过以上分析我们得知：

- 使用sync.Map时，**读操作应尽量保证能够读取到数据，否则仍会进行加锁操作，而且很可能是两次加锁操作。**
- 只要在read中没有读到数据，那么不管是否能够在dirty中读到数据，都会进行missLocked，因此使用sync.Map时，读操作应尽量保证能够读取到数据。

#### read中读不到数据-missLocked

```go
func (m *Map) missLocked() {
	m.misses++
	if m.misses < len(m.dirty) {
		return
	}
	m.read.Store(readOnly{m: m.dirty})
	m.dirty = nil
	m.misses = 0
}
```

missLocked会将misses加1，并且如果此时misses不小于dirty的大小，则会将dirty中的数据覆盖到read，并且重置dirty和misses。

### 写操作-Store

```go
// Store sets the value for a key.
func (m *Map) Store(key, value any) {
	read, _ := m.read.Load().(readOnly)
	if e, ok := read.m[key]; ok && e.tryStore(&value) {
		return
	}

	m.mu.Lock()
	read, _ = m.read.Load().(readOnly)
	if e, ok := read.m[key]; ok {
		if e.unexpungeLocked() {
			// The entry was previously expunged, which implies that there is a
			// non-nil dirty map and this entry is not in it.
			m.dirty[key] = e
		}
		e.storeLocked(&value)
	} else if e, ok := m.dirty[key]; ok {
		e.storeLocked(&value)
	} else {
		if !read.amended {
			// We're adding the first new key to the dirty map.
			// Make sure it is allocated and mark the read-only map as incomplete.
			m.dirtyLocked()
			m.read.Store(readOnly{m: read.m, amended: true})
		}
		m.dirty[key] = newEntry(value)
	}
	m.mu.Unlock()
}

// tryStore stores a value if the entry has not been expunged.
//
// If the entry is expunged, tryStore returns false and leaves the entry
// unchanged.
func (e *entry) tryStore(i *any) bool {
	for {
		p := atomic.LoadPointer(&e.p)
		if p == expunged {
			return false
		}
		if atomic.CompareAndSwapPointer(&e.p, p, unsafe.Pointer(i)) {
			return true
		}
	}
}
```

1. 存储数据时，会先判断read中是否存在该键值对，如果key存在并且没有被标识为删除更新该entry。这个过程是不需要加锁的。
2. 若read中匹配不到该键值对，则会进行加锁，这时候再次读取read，判断read中是否存在key，如果存在（如果存在的entry已经被标为删除，则要将此键值对写入到dirty中），则将value写到对应的key上。

3. 若read中不存在此key，但是dirty中存在，则直接写入到dirty中。
4. 如果read和dirty中都不存在，则将数据写入到dirty中，并判断read的修正标识是否为false，如果是false，则要将修正标识改为true，表示dirty中含有read中不存在的数据。

通过以上分析可知：**写入read中已存在的key，并且该key未被标识为删除，是不需要加锁的。**

### 删除-Delete

```go
// Delete deletes the value for a key.
func (m *Map) Delete(key any) {
	m.LoadAndDelete(key)
}

func (m *Map) LoadAndDelete(key any) (value any, loaded bool) {
	read, _ := m.read.Load().(readOnly)
	e, ok := read.m[key]
	if !ok && read.amended {
		m.mu.Lock()
		read, _ = m.read.Load().(readOnly)
		e, ok = read.m[key]
		if !ok && read.amended {
			e, ok = m.dirty[key]
			delete(m.dirty, key)
			// Regardless of whether the entry was present, record a miss: this key
			// will take the slow path until the dirty map is promoted to the read
			// map.
			m.missLocked()
		}
		m.mu.Unlock()
	}
	if ok {
		return e.delete()
	}
	return nil, false
}

func (e *entry) delete() (value any, ok bool) {
	for {
		p := atomic.LoadPointer(&e.p)
		if p == nil || p == expunged {
			return nil, false
		}
		if atomic.CompareAndSwapPointer(&e.p, p, nil) {
			return *(*any)(p), true
		}
	}
}
```

1. 如果read中有该key，并且read不需要被修正，则直接删除该entry（若该entry已被抹除，或者已经是空指针，则忽略，否则将其赋值为空指针）。
2. 如果read中不存在该key，或者read需要被修正，则判断dirty中是否存在，若已存在，则直接删除。

### 遍历-Range

```go
func (m *Map) Range(f func(key, value any) bool) {
	// We need to be able to iterate over all of the keys that were already
	// present at the start of the call to Range.
	// If read.amended is false, then read.m satisfies that property without
	// requiring us to hold m.mu for a long time.
	read, _ := m.read.Load().(readOnly)
	if read.amended {
		// m.dirty contains keys not in read.m. Fortunately, Range is already O(N)
		// (assuming the caller does not break out early), so a call to Range
		// amortizes an entire copy of the map: we can promote the dirty copy
		// immediately!
		m.mu.Lock()
		read, _ = m.read.Load().(readOnly)
		if read.amended {
			read = readOnly{m: m.dirty}
			m.read.Store(read)
			m.dirty = nil
			m.misses = 0
		}
		m.mu.Unlock()
	}

	for k, e := range read.m {
		v, ok := e.load()
		if !ok {
			continue
		}
		if !f(k, v) {
			break
		}
	}
}
```

1. 如果read不需要被修正，则进行读取read中的数据
2. 如果read需要被修正，则需要加锁，并将dirty中的数据覆盖到read中

## 设计点

### 双map

sync.Map中定义了两个map：一个read，用于只读；一个dirty，用于存储read中不存在的值。

通过这两种方式**实现了部分操作的lock-free**，这些操作有：

- 读取read已存在的key或者读取时read不需要被修正。
- 更新read中已有key，并且该key未标识为删除。
- 删除read已存在的key或者删除时read不需要被修正。

### 更新数据的lock-free

删除数据的lock-free是通过entry实现的。

使用指针来存储value（将value抽象为entry），使得sync.Map可以直接通过原子操作来修改value。

这个过程中与map的读写无关。sync.Map通过这种方式实现了更新数据的lock-free.

### 删除数据的lock-free

在更新数据的lock-free基础上，删除数据的lock-free还使用了expunged。

sync.Map为了避免加锁，定义了一个删除指针expunged。当删除key时，如果read中存在该数据，则将value的指针地址指向这个删除指针即可。当访问该key时，sync.Map会判断entry为expunged，因此返回零值.

这个过程中与map的读写无关。sync.Map通过这种方式实现了删除数据的lock-free.

## 总结

我们不能单纯的说sync.Map适用于读多写少的场景——毕竟更新和删除操作很可能也是lock-free的。

对于**不能使用sync.Map的使用场景**我们可以归纳为：

- 读操作多且经常读不存在的数据：这时候读操作还是通过加锁来读取dirty（而且还是加两次锁）。
- 经常写入新key：写入新key是一定要加锁的。
- 大量删除、更新的操作，并且访问的数据不存在：更新、删除不存在的数据也是要加锁的。
