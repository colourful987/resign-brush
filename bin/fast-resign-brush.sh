#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function run {
	echo "[√] Executing command: $@"
	$@
	if [[ $? != "0" ]]; then
		echo "[×] Executing the above command has failed!"
		exit 1
	fi
}

function run_at {
	pushd "$1" > /dev/null 2>&1
	shift > /dev/null 2>&1
	run "$@" > /dev/null 2>&1
	popd > /dev/null 2>&1
}

function verify_certificate {
	echo "[∞] 开始证书验证..."
	local cert="$1"
	local search=$(security find-identity -v -p codesigning | grep "$cert")

	if [[ -z "${search}" ]]; then
		echo "[×] 签名证书 ${cert} 未找到，为你找到当前可用的证书"
		list_available_certificates
		exit 1
	fi

	echo "[√] 证书验证通过"
}

function list_available_certificates {
	run "security find-identity -v -p codesigning"
}

function create_workspace_dir {
	local dir="$1"

	if [[ ! -d "${dir}" ]]; then
	    echo "[∞] 开始创建临时工作目录..."
		run "mkdir ${dir}"
		echo "[√] 创建成功：${dir} "
	fi
}

function prepare_app_package {
	local workspace_dir="$1"
	local source_file="$2"
	local source_ext=${source_file##*.}

	# (optional) ipa 文件转成 app 文件
	if [[ ${source_ext} == "ipa" ]]; then

		if [[ ! -f "${source_file}" ]]; then
			echo "[×] 未找到 ipa 应用程序，请检查路径：${source_file}"
			exit 1
		fi
		run_at "${workspace_dir}" "unzip -qo ${source_file}"

	elif [[ ${source_ext} == "app" ]]; then
		if [[ ! -d "${source_file}" ]]; then
			echo "[×] 未找到 app 应用程序，请检查路径：${source_file}"
			exit 1
		fi

		run_at "${workspace_dir}" "mkdir Payload"
		run_at "${workspace_dir}" "cp -rf ${source_file} Payload"
	else
		echo "[×] 当前仅支持 .ipa 和 .app 程序包格式"
		exit 1
	fi
}

APS_ENV="production"
function check_aps_environment {
    local workspace_dir="$1"

    cd ${workspace_dir}
    # ========================= 作用域是新创建的工作区 =====================
	APP="$(find $(pwd) -name "*.app" | head -n 1)"
	if [[ -z "${APP}" ]]; then
		echo "[×] 工作区未找到可用的 .app 文件！"
		exit 1
	fi
	origin_prov_file="${APP}/embedded.mobileprovision"

	security cms -D -i ${origin_prov_file} > origin-embedded.plist
	aps_env=$(/usr/libexec/PlistBuddy -c 'Print:Entitlements:aps-environment' origin-embedded.plist)

	if [[ "${aps_env}" != "" ]]; then
	    APS_ENV=${aps_env}
	else
	    echo "[!] 应用程序无法确定包类型，使用默认签名"
	fi
    # ====================================================================
	cd - # 恢复目录
}

function check_provision_file {
    local prov_file="$1"

    # 描述文件检查
    if [[ ! "${prov_file}" =~ "embedded.mobileprovision" ]]; then
        echo "[×] 描述文件必须以 embedded.mobileprovision 命名"
        exit 1
    fi

    if [[ ! -f "${prov_file}" ]]; then
        echo "[×] 未找到描述文件，请检查文件路径:${prov_file}"
        exit 1
    fi
}

# 重签名应用程序
function resign {
	local certificate_name="$1"
	local provision_file="$2"
	local workspace_dir="$3"
	local source_file="$4"
	local target_file="$5"

	cd ${workspace_dir}

	# ========================= 作用域是新创建的工作区 =====================
	APP="$(find $(pwd) -name "*.app" | head -n 1)"

	if [[ -z "${APP}" ]]; then
		echo "[×] 工作区未找到可用的 .app 文件！"
		exit 1
	fi

	run "cp ${provision_file} ." 
	security cms -D -i ${provision_file} > embedded.plist
	/usr/libexec/PlistBuddy -x -c 'Print:Entitlements' embedded.plist > entitlements.plist

	payload_dir="${workspace_dir}/Payload"

	# 删除旧的签名文件
	find ${payload_dir} -d -name "_CodeSignature" | xargs rm -rf

	# 查找要重签名的所有文件清单
	find ${payload_dir} -d \( -name "*.app" -o -name "*.appex" -o -name "*.framework" -o -name "*.dylib" \) > resign-list.txt

	if [[ ! -f resign-list.txt ]]; then
		echo "[×] 应用中未找到可重签名的项目！"
		exit 1
	fi

	while IFS='' read -r file_2_resign || [[ -n "$file_2_resign" ]]; do
		ret=$(/usr/bin/codesign -f -s "${certificate_name}" --entitlements entitlements.plist "$file_2_resign"  > /dev/null 2>&1)
		if [[ "$ret" =~ "no identity found" ]]; then
		    echo "[×] resign failed：${file_2_resign} check certificate name"
		    exit 1
		fi
		echo "[√] resign ：${file_2_resign##*/}"
	done < resign-list.txt

    echo "[√] app resign complete, check result."
	echo "----------------------------------------------------------------"
	codesign -vv -d "${APP}"
	echo "----------------------------------------------------------------"
	# =========================			end 		  ======================
	cd - # 恢复目录
}

function output_target_file {
    local workspace="$1"
    local output_file="$2"

    payload_dir="${workspace}/Payload"

    if [[ ! -d "${payload_dir}" ]]; then
		echo "[×] 工作区未找到 Payload 目录，导出重签名包失败"
		exit 1
	fi

    APP=$(find ${workspace} -type d | grep ".app$" | head -n 1)

	local output_file_ext="${output_file##*.}"

	if [[ "${output_file_ext}" == "ipa" ]]; then
	    echo "[∞] 正在导出重签名后的应用程序(.ipa) ..."
        run_at "${workspace}" "zip -qr Target.ipa Payload"
        run_at "${workspace}" "cp -rf Target.ipa $output_file"
        echo "[√] 请前往 ${output_file} 查看生成文件"
	elif [[ "${output_file_ext}" == "app" ]]; then
	    echo "[∞] 正在导出重签名后的应用程序(.app) ..."
        run_at "${payload_dir}" "cp -rf ${APP} $output_file"
        echo "[√] 请前往 ${output_file} 查看生成文件"
	else
	    echo "[×] 输出文件路径请指定 ipa 或是 app！"
	    exit 1
	fi

}

######################################################
#
# 可选证书都传入，内部做区分，测试催得急，直接CV。有缘人来重写
#
######################################################
# 证书和描述文件
CERTIFICATE_NAME="$1"
EMBEDDED_MOBILEPROVISION_FILE="$2"

# 要重签名的程序包，支持 app 和 ipa
SOURCE_FILE="$3"
# 重签名完的目标程序包，可以是 app 和 ipa
TARGET_FILE="$4"

# 创建工作目录
TMP_WORKSPACE_DIR="/tmp/resign-brush-"$(uuidgen)
create_workspace_dir "${TMP_WORKSPACE_DIR}"

# 准备 app 应用程序包，如果是 ipa 则要转成 app 文件
prepare_app_package "${TMP_WORKSPACE_DIR}" "${SOURCE_FILE}"

# 检查安装的应用程序包是什么环境
check_aps_environment "${TMP_WORKSPACE_DIR}"

# 根据环境确定用什么证书和描述文件
if [[ "${APS_ENV}" == "development" ]]; then
    if [[ "${CERTIFICATE_NAME}" =~ "Developer" ]]; then
        echo "[√] 检测到传入的应用程序包为开发版本，请确保你的 ${CERTIFICATE_NAME} 证书也为开发证书"
    else
        echo "[×] 检测到传入的应用程序包为开发版本，你的证书 ${CERTIFICATE_NAME} 非开发证书，不符合要求！"
    fi
else
      if [[ "${CERTIFICATE_NAME}" =~ "Distribution" ]]; then
        echo "[√] 检测到传入的应用程序包为发布版本，请确保你的 ${CERTIFICATE_NAME} 证书也为发布证书"
    else
        echo "[×] 检测到传入的应用程序包为发布版本，你的证书 ${CERTIFICATE_NAME} 非发布证书，不符合要求！"
    fi

fi

# 查询可签名证书（配置文件用默认自带的）
verify_certificate "${CERTIFICATE_NAME}"

# 检查描述文件命名是否正确，是否存在
check_provision_file "${EMBEDDED_MOBILEPROVISION_FILE}"

# 重签名
resign "${CERTIFICATE_NAME}" "${EMBEDDED_MOBILEPROVISION_FILE}" "${TMP_WORKSPACE_DIR}" "${SOURCE_FILE}"

# 将重签名的程序包放到指定位置，若为 ipa 还需要做一个转换
output_target_file "${TMP_WORKSPACE_DIR}" "${TARGET_FILE}"














