# Resign Brush

resign for `*.ipa/*.app` with your own certificate and provisioning profile. Once resign, you can install app in your iPhone.

## Getting Started

Start by using `python3.7 resign_brush -h` to get all usage.

```shell
usage: resign_brush.py [-h] {doctor,fast-resign} ...

positional arguments:
  {doctor,fast-resign}
    doctor              检查 resign brush 依赖环境
    fast-resign         使用证书和描述文件重签名应用程序包

optional arguments:
  -h, --help            show this help message and exit
  
```

You can resign an app with `python3.7 resign_brush.py fast-resign` cmd. However, make sure you have an valid certificate and provisioning profile which named embedded.mobileprovision:

```shell
~# : python3.7 resign_brush.py fast-resign -h
usage: resign_brush.py fast-resign [-h] -c CERT -p PROVISION -a APP -o OUTPUT

optional arguments:
  -h, --help            show this help message and exit
  -c CERT, --cert CERT  请输入有效签名的开发证书或发布证书名，支持企业证书（299$），公司证书(99$，非下面分配的开发者证书)，
                        独立开发者证书(99$，仅此一号)
  -p PROVISION, --provision PROVISION
                        配套的描述文件(embedded.mobileprovision)路径，unzip your app to
                        search and get it.
  -a APP, --app APP     原始应用程序包文件路径，支持 .ipa 和 .app 格式
  -o OUTPUT, --output OUTPUT
                        签名后的程序包，支持 .ipa 和 .app 格式
```

### Deploying

Here Provide **setup.py**， so you can use setuptools to install it like this .  

```shell
python3.7 setup.py sdist

pip3.7 install dist/resign-brush-1.0.0.tar.gz

# now you can use resign-brush anywhere
resign-brush -h
```



## Contributing

