#!/bin/bash
# 交叉编译到 Android: GOOS=android GOARCH=arm64 go build -o synsurveyd main.go
cd "/bin/synsurveyd" && GOOS=android GOARCH=arm64 go build -o synsurveyd main.go && echo "=> synsurveyd"
