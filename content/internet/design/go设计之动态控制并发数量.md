+++

date = 2023-08-22T19:43:00+08:00
title = "go设计之动态控制并发数量"
url = "/internet/go/concurrent_control"

toc = true

+++



在生产中，我们常常需要并发处理任务，这时就需要动态控制并发的数量：

1. 并发数不能超过最大值：并发数量过大容易导致过度使用系统资源。
1. 并发数不能低于最小值：并发数较小会使得任务处理速度变慢。
1. 动态控制并发数量：任务多时，并发量应变大以加快任务处理速度；任务少时，并发量要降低以释放资源。

针对以上需求，我们抽象出了几种结构：

- **Worker**：用于处理任务
- **WorkerManager**：用于控制并发数量

在golang中，有以下几种方式可以实现。

## 方法1：使用channel来实现Worker

使用Channel来实现Worker，控制并发数量就可以通过生成新的Channel或者关闭Channel来实现。

### Worker实现

```go
const workerCap = 100

type Worker chan any

func (w Worker) Work() {
	for job := range w {
		doJob(job)
	}
}

func (w Worker) Receive(job any) {
	w <- job
}

func (w Worker) Close() {
	close(w)
}

func NewWorker() Worker {
	return make(chan any, workerCap)
}

func doJob(job any) {
	fmt.Println("handling a job")
	time.Sleep(time.Millisecond * 100) // mock task exec
}
```

### WorkerManager实现

workerManager需要控制Worker，设置最大并发数和最小并发数：

```go
type WorkerManger struct {
	maxWorker int
	minWorker int

	Workers []Worker
	lock    sync.RWMutex
}

func NewWorkerManager(maxWorker, minWorker int) *WorkerManger {
	manager := &WorkerManger{
		maxWorker: maxWorker,
		minWorker: minWorker,
	}
	for i := 0; i < minWorker; i++ {
		manager.addWorker()
	}
	go manager.scale()
	return manager
}
```

在服务运行中，会通过控制worker的数量来控制并发数量：

```go
type status int

const (
	idle status = iota
	normal
	busy
)

func (wm *WorkerManger) scale() {
	for {
		switch wm.status() {
		case busy:
			wm.addWorker()
		case idle:
			wm.remWorker()
		case normal:
		}
		time.Sleep(time.Millisecond * 10)
	}
}
```

查看当前的任务处理状态（我们假设当任务数量大于当前worker数量的两倍时为繁忙，任务数量小于当前worker数量的一半时为空闲）：

```go
func (wm *WorkerManger) status() status {
	wm.lock.RLock()
	defer wm.lock.RUnlock()

	jobCnt := 0
	for _, worker := range wm.Workers {
		jobCnt += len(worker)
	}
	if jobCnt > len(wm.Workers)*2 {
		return busy
	}
	if jobCnt < len(wm.Workers)/2 {
		return idle
	}
	return normal
}
```

任务繁忙时，需要增加worker：

```go
func (wm *WorkerManger) addWorker() {
	fmt.Println("adding worker")
	wm.lock.RLock()
	if len(wm.Workers) >= wm.maxWorker {
		fmt.Println("worker num arrives max")
		wm.lock.RUnlock()
		return
	}
	wm.lock.RUnlock()

	wm.lock.Lock()
	defer wm.lock.Unlock()

	worker := NewWorker()
	go worker.Work()
	wm.Workers = append(wm.Workers, worker)
	return
}
```

任务空闲时，需要减少worker：

```
func (wm *WorkerManger) remWorker() {
	fmt.Println("removing worker")
	wm.lock.RLock()
	if len(wm.Workers) <= wm.minWorker {
		fmt.Println("worker num arrives min")
		wm.lock.RUnlock()
		return
	}
	wm.lock.RUnlock()

	wm.lock.Lock()
	defer wm.lock.Unlock()

	for i, worker := range wm.Workers {
		if len(worker) == 0 {
			fmt.Println("removing ", i, "st worker")
			worker.Close()
			wm.Workers = append(wm.Workers[:i], wm.Workers[i+1:]...)
			return
		}
	}
}
```

当接收到任务时，需要随机获取一个worker来处理任务：

```go
func (wm *WorkerManger) Do(job any) {
	worker := wm.getWorker()
	worker.Receive(job)
}

func (wm *WorkerManger) getWorker() Worker {
	wm.lock.RLock()
	defer wm.lock.RUnlock()
	idx := rand.Intn(len(wm.Workers))
	return wm.Workers[idx]
}
```

以上就是全部代码了，执行一下：

```go
func main() {
	manager := NewWorkerManager(10, 2)
	for i := 0; i < 15; i++ {
		manager.Do(i)
	}

	time.Sleep(time.Second * 5)
}
```

输出：

```shell
# 创建管理器时设置了两个worker
adding worker
adding worker
# 刚创建完没任务需要处理
removing worker
worker num arrives min
## 处理任务，输出乱序了
handling a job
handling a job
adding worker
adding worker
adding worker
adding worker
adding worker
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
handling a job
# 处理完任务进入idle状态，需要移除worker
removing worker
removing  0 st worker
removing worker
removing  1 st worker
handling a job
removing worker
removing  1 st worker
removing worker
removing  1 st worker
handling a job
removing worker
removing  0 st worker
removing worker
# 到达了最小并发数
worker num arrives min
```

## 方法2：使用协程实现Worker

我们可以让Worker上报自己当前的状态——是繁忙还是空闲，如果有的worker空闲，那么需要释放worker；如果没有worker空闲，那么说明当前任务处理繁忙，需要新增worker。

### Worker实现

抽象Worker为接口，这样Worker管理器就可以成为通用的组件。

```go
type Worker interface {
	GetDataChannel() <-chan interface{}
	HandleData(interface{})
	CloseChannel()
}
```

### WorkerManager实现

```go
type WorkerManager struct {
	maxWorker      int // 最大并发数
	minWorker      int // 最小并发数
	currentWorkerNum *int32 // 当前的并发数 
	reportStatus   chan status // 汇报状态的channel

	closeChan   chan struct{} // 用于通知关闭的channel
	newWorkerFnc func() Worker // 创建新worker的函数
}

func NewWorkerManager(maxWorker, minWorker int, newWorkerFnc func() Worker) *WorkerManager {
	if maxWorker < minWorker {
		panic("maxWorker can't be less than minWorker")
	}
	if minWorker <= 0 {
		minWorker = 1
	}
	zeroNum := int32(0)
	s := &WorkerManager{
		maxWorker:      maxWorker,
		minWorker:      minWorker,
		reportStatus:   make(chan status, maxWorker),
		closeChan:      make(chan struct{}),
		newWorkerFnc:    newWorkerFnc,
		currentWorkerNum: &zeroNum,
	}

	for i := 0; i < minWorker; i++ {
		go s.newWorker()
	}
	go s.Manage()
	return s
}
```

动态管理并发数：

```go
// Manage 管理线程逻辑
// 释放逻辑：当连续n次获取数据超时，并且休眠worker数小于最大的休眠worker数量，则释放worker
// 新建逻辑：当5秒内没有空闲worker时，新建worker
func (s *WorkerManager) Manage() {
	timer := time.NewTimer(time.Second * 5)
	for {
		select {
		case <-s.closeChan:
			return
		case <-s.reportStatus:
			break
		case <-timer.C: // not get any signal means that every thread is working
			if atomic.LoadInt32(s.currentWorkerNum) >= int32(s.maxWorker) {
				continue
			}
			go s.newWorker()
		}
		fmt.Println("current num", atomic.LoadInt32(s.currentWorkerNum))
		timer.Reset(time.Second * 5)
	}
}
```

创建新worker：当超过一段时间没有获取到任务后就上报自己的空闲状态。

```go
func (s *WorkerManager) newWorker() {
	fmt.Println("new worker")
	consumer := s.newWorkerFnc()
	timeoutTimer := time.NewTimer(time.Second)
	timeoutNum := 0
	atomic.AddInt32(s.currentWorkerNum, 1)
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("recover", r)
		}
		atomic.AddInt32(s.currentWorkerNum, -1)
		fmt.Println("release worker")
	}()
	needClose := false
	for {
		select {
		case data, ok := <-consumer.GetDataChannel():
			if ok {
				consumer.HandleData(data)
				timeoutNum = 0
			} else { // consumer channel closed
				return
			}
		case <-timeoutTimer.C:
			timeoutNum++
			s.reportStatus <- idleStatus
		case <-s.closeChan:
			needClose = true
		}
		if timeoutNum >= 3 && atomic.LoadInt32(s.currentWorkerNum) > int32(s.minWorker) {
			needClose = true
		}
		if needClose {
			consumer.CloseChannel() // wait consumer close, so that we can avoid lose data in the consumer channel
			for data := range consumer.GetDataChannel() {
				consumer.HandleData(data)
			}
			return
		}
		timeoutTimer.Reset(time.Second)
	}
}
```



