import argparse
import subprocess
import sys
import re
from configs.brush_configs import *


def run_shell(shell):
    cmd = subprocess.Popen(shell, stdin=subprocess.PIPE, stderr=sys.stderr, close_fds=True,
                           stdout=sys.stdout, universal_newlines=True, shell=True, bufsize=1)
    cmd.communicate()
    return cmd.returncode


def find_executable(executable):
    path = os.environ['PATH']
    paths = path.split(os.pathsep)
    base, ext = os.path.splitext(executable)
    if sys.platform == 'win32' and not ext:
        executable = executable + '.exe'

    if os.path.isfile(executable):
        return executable

    for p in paths:
        full_path = os.path.join(p, executable)
        if os.path.isfile(full_path):
            return full_path

    return None


def doctor_check_required_cmds():
    find_res = find_executable("ios-deploy")
    if find_res is None:
        print('[×] ios-deploy is not installed, You can use homebrew install it easily.')
    else:
        print('[√] ios-deploy is installed, locate in {cmd}'.format(cmd=find_res))

    find_res = find_executable("ideviceinstaller")
    if find_res is None:
        print('[×] libimobiledevice is not installed, You can use homebrew install it easily.')
    else:
        print('[√] libimobiledevice is installed, locate in {cmd}'.format(cmd=find_res))


def doctor_check_certificats():
    cmd = "security find-identity -v -p codesigning"
    (status, output) = subprocess.getstatusoutput(cmd)
    if status != 0:
        print('[×] security find-identity failed')
        return

    ids = {}
    for current in output.split("\n"):
        sha1obj = re.search("[a-zA-Z0-9]{40}", current)
        nameobj = re.search(".*\"(.*)\"", current)

        if sha1obj is None or nameobj is None:
            continue
        sha1 = sha1obj.group()
        name = nameobj.group(1)
        ids[sha1] = name

    print("\t------------------------------------ Identity List -----------------------------------")
    for name in ids:
        print("\t{name} : {sha1}".format(name=name, sha1=ids[name]))
    print("\t--------------------------------------------------------------------------------------")


def run_doctor(args):
    """
    检查环境配置：内置证书是否安装，ios-deploy 和 libimobiledevice 三方库是否安装
    :param args:
    :return:
    """
    # 检查 ios-deploy 和 libimobiledevice
    doctor_check_required_cmds()

    # 检查证书是否安装
    doctor_check_certificats()


def fast_resign(args):
    resign_script = os.path.join(BRUSH_BIN_DIR, "fast-resign-brush.sh")

    certificate = args.cert
    prov_file = args.provision

    cmd = 'sh "{script}" "{cert}" "{provision}" "{app}" "{output}"'.format(
        script=resign_script,
        cert=certificate,
        provision=prov_file,
        app=args.app,
        output=args.output)

    status = run_shell(cmd)

    if status == 0:
        print("✿✿ヽ(°▽°)ノ✿ 重签名成功")
    else:
        print("(灬ꈍ ꈍ灬) 重签名失败")
    exit(status)


def brush_entry():
    """
    脚本选项解析，当前支持 doctor, resign 选项
    """
    parser = argparse.ArgumentParser()
    sub_parsers = parser.add_subparsers()

    doctor_parser = sub_parsers.add_parser("doctor", help="检查 resign brush 依赖环境")
    doctor_parser.set_defaults(callback=run_doctor)
    doctor_parser.add_argument("--verbose", action="store_true", help="输出详细的检查日志")

    fast_resign_parser = sub_parsers.add_parser("fast-resign", help="使用证书和描述文件重签名应用程序包")
    fast_resign_parser.set_defaults(callback=fast_resign)
    fast_resign_parser.add_argument("-c", "--cert", help="请输入有效签名的开发证书或发布证书名，支持企业证书（299$），公司证书(99$，非下面分配的开发者证书)，独立开发者证书(99$，仅此一号)", required=True)
    fast_resign_parser.add_argument("-p", "--provision", help=" 配套的描述文件(embedded.mobileprovision)路径，unzip your app to search and get it.", required=True)
    fast_resign_parser.add_argument("-a", "--app", help="原始应用程序包文件路径，支持 .ipa 和 .app 格式", required=True)
    fast_resign_parser.add_argument("-o", "--output", help="签名后的程序包，支持 .ipa 和 .app 格式", required=True)

    args = parser.parse_args()
    args.callback(args)


if __name__ == '__main__':
    brush_entry()
