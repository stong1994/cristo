hugo -d docs
cp -rf docs/* ../stong1994.github.io/docs
cd ../stong1994.github.io/
git add * && git commit -m "save article" && git push
cd -
