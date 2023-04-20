#!/bin/sh
set -e
function log()
{
    echo $1 | tee -a ./update/copy.txt
}

param_pattern="p:"
OPTIND=1
mainPath=""
while getopts $param_pattern optname
    do
        tmp_optind=$OPTIND
        tmp_optname=$optname
        tmp_optarg=$OPTARG

        OPTIND=$OPTIND-1
        if getopts $param_pattern optname ;then
            echo $param_pattern
            echo  "Error: argument value for option $tmp_optname"
            usage
            exit 2
        fi

        OPTIND=$tmp_optind
        optname=$tmp_optname

        case "$optname" in
            "p")
                mainPath=$tmp_optarg
                ;;
            "?")
                echo "Error: Unknown option $OPTARG"
                usage
                exit 2
                ;;
            ":")
                echo "Error: No argument value for option $OPTARG"
                usage
                exit 2
                ;;
            *)
              # Should not occur
                echo "Error: Unknown error while processing options"
                usage
                exit 2
                ;;
        esac
    done

echo $mainPath
if [ -z "$mainPath" ];then
    exit 2
fi
log "替换地址 "$mainPath

if [[ -z "$mainPath/path.json" ]];then
    echo "路径为空 无法处理!"
    exit 2
fi

config=$(cat $mainPath/path.json | sed -r 's/",/"/' | egrep -v '^[{}]' | sed 's/"//g' | sed 's/:/=/1' | sed -r 's/ //g')
declare $config

if [[ -z "$localPath" ]];then
    echo "路径为空 无法处理!"
    exit 2
fi

if [[ -z "$name" ]];then
    echo "文件名为空 无法处理!"
    exit 2
fi

localfilePath="$(find $mainPath -type f -name 本地*)"
workfilePath="$(find $mainPath -type f -name 替换*)"
filePath=""
if [[ ${#localfilePath[@]} > 1 ]];then
    echo "本地文件有多个 无法处理!"
    exit 2
fi

if [[ ${#workfilePath[@]} > 1 ]];then
    echo "替换文件有多个 无法处理!"
    exit 2
fi

if [[ -f $localfilePath &&  -f $workfilePath ]];then
    echo "请删除本地文件或替换文件 \n脚本将自动选中剩下的那个"
    exit
else
    if [[ ! -f $workfilePath && ! -f $localfilePath ]];then
        echo "缺少文件"
        exit 2
    else
        if [ -f $localfilePath ];then
            filePath=$localfilePath
        else
            filePath=$workfilePath
        fi
    fi
fi

log "\n"
log "文件 $filePath"
log "复制到 $copyPath"
log "并删除 $mainPath"
echo "是否复制? (y/n)"
read confirmation
if [ "$confirmation" == "y" ]; then
    cp $filePath $localPath
    rm -rf $mainPath
    log "[删除]"
    exit
else
    log "[未删除]"
    exit
fi

