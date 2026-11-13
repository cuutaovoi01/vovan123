# KFCrossOverIPC (fixed)

Bản thay thế `libCrossOverIPC.dylib` cho Kids (`kidsdaemon`), sửa bug singleton:
mỗi center là instance riêng nên `registerForMessageName:` + `sendMessageName:` hoạt động đúng
(login result IPC không bị mất do center tạo sau ghi đè).

## Build

GitHub Actions: push lên repo → Actions → build → tải artifact `libCrossOverIPC`.

Hoặc local (macOS):
```sh
./build.sh
```

## Cài lên máy

```sh
# backup
cp -p /var/jb/usr/lib/libCrossOverIPC.dylib /var/jb/usr/lib/libCrossOverIPC.dylib.orig
# thay
cp libCrossOverIPC.dylib /var/jb/usr/lib/libCrossOverIPC.dylib
chmod 755 /var/jb/usr/lib/libCrossOverIPC.dylib
ldid -S /var/jb/usr/lib/libCrossOverIPC.dylib
killall -9 kidsdaemon
```

## Kiểm tra

```sh
curl http://127.0.0.1:16688/license
```

## Ghi chú

- Build bằng `xcrun clang` (ld64) — không dùng lld cross vì arm64e bind opcodes không tương thích dyld iOS 16.
- Cần `arm64e` slice cho daemon trên A12+.
