#!/bin/bash
# 交叉编译到 Android: GOOS=android GOARCH=arm64 go build -o synpadd main.go
cd "/bin/synpadd" && GOOS=android GOARCH=arm64 go build -o synpadd main.go && echo "=> synpadd"
