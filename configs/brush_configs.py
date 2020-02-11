import os

# 配置文件完整路径
BRUSH_CONFIGS_FILE_PATH = os.path.abspath(__file__)

# 配置文件目录
BRUSH_CONFIGS_DIR = os.path.dirname(BRUSH_CONFIGS_FILE_PATH)

# 工作区目录
BRUSH_WORKSPACE = os.path.dirname(BRUSH_CONFIGS_DIR)

# bin 目录
BRUSH_BIN_DIR = os.path.join(BRUSH_WORKSPACE, "bin")

# brush core 目录
BRUSH_CORE_DIR = os.path.join(BRUSH_WORKSPACE, "brush_core")

# 证书 描述文件目录
BRUSH_CERT_DIR = os.path.join(BRUSH_WORKSPACE, "cert")
BRUSH_CERT_DEBUG_DIR = os.path.join(BRUSH_CERT_DIR, "debug")
BRUSH_CERT_INHOUSE_DIR = os.path.join(BRUSH_CERT_DIR, "inhouse")

