#!/bin/bash
# 交叉编译到 Android: GOOS=android GOARCH=arm64 go build -o synrelayd main.go
cd "/bin/synrelayd" && GOOS=android GOARCH=arm64 go build -o synrelayd main.go && echo "=> synrelayd"
