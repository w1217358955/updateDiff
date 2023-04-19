#!/bin/sh
set -e
function getType()
{
    local filename=$1
    for ctype in "${codeTypes[@]}"
    do
        if [[ "$ctype" =~ "." ]]; then
            if [[ "$filename" == *$ctype ]]; then
                echo "[代码文件]" | tee -a $dicPath/log.txt
                fileType="code"
                return
            fi
        else
            if [[ "$filename" == $ctype ]]; then
                echo "[代码文件]" | tee -a $dicPath/log.txt
                fileType="code"
                return
            fi
        fi
    done
    for ctype in "${txtTypes[@]}"
    do
        if [[ $ctype =~ "." ]]; then
            if [[ "$filename" == *$ctype ]]; then
                echo "[文本文件]" | tee -a $dicPath/log.txt
                fileType="txt"
                return
            fi
        else
            if [[ "$filename" == $ctype ]]; then
                echo "[文本文件]" | tee -a $dicPath/log.txt
                fileType="txt"
                return
            fi
        fi
    done
    for ctype in "${imgTypes[@]}"
    do
        if [[ $ctype =~ "." ]]; then
            if [[ "$filename" == *$ctype ]]; then
                echo "[图片文件]" | tee -a $dicPath/log.txt
                fileType="img"
                return
            fi
        else
            if [[ "$filename" == $ctype ]]; then
                echo "[图片文件]" | tee -a $dicPath/log.txt
                fileType="img"
                return
            fi
        fi
    done
    echo "[未知文件]" | tee -a $dicPath/log.txt
    fileType="unknow"
    return
}

function log()
{
    echo $1 | tee -a $dicPath/log.txt
}

function random()
{
    min=1;
    max=10000000;
    num=$(date +%s+%N);
    ((randomNum=num%max+min));
}

param_pattern="j:r:w:l:a:b:"
OPTIND=1
judgementWord="wink;"
replaceWord="NG;"

config=$(cat sh-config.json | sed -r 's/",/"/' | egrep -v '^[{}]' | sed 's/"//g' | sed 's/:/=/1' | sed -r 's/ //g')
declare $config

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
            "j")
                judgementWord=$tmp_optarg
                IFS=';' read -ra judgementWords <<< "$judgementWord"
                ;;
            "r")
                replaceWord=$tmp_optarg
                ;;
            "w")
                workPath=$tmp_optarg
                ;;
            "l")
                localPath=$tmp_optarg
                ;;
            "a")
                aCommit=$tmp_optarg
                ;;
            "b")
                bCommit=$tmp_optarg
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
    
IFS=';' read -ra txtTypes <<< "$txtType"
IFS=';' read -ra codeTypes <<< "$codeType"
IFS=';' read -ra imgTypes <<< "$imgType"

mainPath=$(pwd)

dicPath=$mainPath/update
if [ ! -d $dicPath ];
then
    mkdir $dicPath
else
    rm -rf $dicPath
    mkdir $dicPath
fi

echo $mainPath
log "工作目录 "$workPath
log "本地目录 "$localPath

if [ ! -d $workPath/.git ];then
    echo "工作目录缺少git配置"
    exit 2
fi

cd $localPath
localPath=$(pwd)
if [ "$(git diff HEAD)" == "" ];then
    echo "本地仓库无修改"
else
    echo "本地仓库有修改, 是否退出自行处理? (y/n)"
    read confirmation
    if [ "$confirmation" == "y" ]; then
        exit
    else
        git clean -df
        git checkout HEAD
        git reset --hard HEAD
    fi
fi

cd $mainPath

cd $workPath
workPath=$(pwd)
git clean -df
git checkout $bCommit

IFS=';' read -ra judgementWords <<< "$judgementWord"
for i in "${judgementWords[@]}"
do
    log "需规避单词 ""$i"
done

IFS=';' read -ra replaceWords <<< "$replaceWord"
for i in "${replaceWords[@]}"
do
    log "需替换单词 ""$i"
done

git diff "7efdb553bd" "e336323ab3" --name-only > $dicPath/diff.txt
diffContent=$(cat $dicPath/diff.txt | tr "\n" ";")
IFS=';' read -ra diffs <<< "$diffContent"

fileNumber=0
for item in "${diffs[@]}";
do
    file="$item"
    fileName=${file##*/}
    fileExtension=${fileName##*.}
    filePath=$(dirname "$file")
    this_time=$(date +%s%N)
    log "\n[准备替换]: ""$file"
    log "文件名"$fileName
    log "后缀"$fileExtension
    log "文件目录""$filePath"
    log "时间"$this_time
    ((fileNumber++))
    fileDiff=$(git diff $aCommit $bCommit -- ./$file)
    getType $fileName
    #替换目录没这个文件或者diff告知是删除文件
    if [[ ! -f $workPath/$file || $fileDiff =~ "deleted file mode" ]];
    then
        rm -rf $localPath/$file
        log "[文件 ---> 删除]\n"$localPath/$file
        continue
    fi
    #本地没这个文件或者diff告知是新文件
    if [[ ! -f $localPath/$file || $fileDiff =~ "new file mode" ]];
    then
        log "[文件 ---> 新增]\n"$localPath/$file
        log "复制文件 "$localPath/"$file"
        if [ ! -d $localPath/"$filePath" ];
        then
            mkdir -p $localPath/"$filePath"
        fi
        
        if [ -d $workPath/"$file" ];
        then
            cp -r $workPath/"$file" $localPath/"$file"
        else
            cp $workPath/"$file" $localPath/"$file"
        fi
        continue
    else
        echo "[文件 ---> 修改]" | tee -a $dicPath/log.txt
        if [[ "$fileType" == "img" || "$fileType" == "unknow" ]];
        then
            if [ ! -d $dicPath/$fileType ];
            then
                mkdir $dicPath/$fileType
            fi
            fileDic=$dicPath/$fileType/$fileName
            if [ ! -d $fileDic ];
            then
                mkdir $fileDic
            else
                fileDic=$fileDic"_$fileNumber"
                mkdir "$fileDic"
            fi
            cp $workPath/"$file" $fileDic/替换文件.$fileExtension
            cp $localPath/"$file" $fileDic/本地文件.$fileExtension
            echo $file | tee -a $fileDic/diff.txt
            log "复制双文件到 "$fileDic
            continue
        fi
        if [[ "$fileType" == "code" || "$fileType" == "txt" ]];
        then
            hasJudgement=false
            for judgementWord in "${judgementWords[@]}"
            do
                if [ `grep -c "$judgementWord" $localPath/"$file"` -ne '0' ];
                then
                    if [ ! -d $dicPath/$fileType ];
                    then
                        mkdir $dicPath/$fileType
                    fi
                    fileDic=$dicPath/$fileType/$fileName
                    if [ ! -d $fileDic ];
                    then
                        mkdir $fileDic
                    else
                        fileDic=$fileDic"_$fileNumber"
                        mkdir $fileDic
                    fi
                    log "本地文件命中规避词 "$judgementWord | tee -a $fileDic/diff.txt
                    cp $workPath/"$file" $fileDic/替换文件.$fileExtension
                    cp $localPath/"$file" $fileDic/本地文件.$fileExtension
                    echo $file | tee -a $fileDic/path.txt
                    git diff $aCommit $bCommit -- ./$file | tee -a $fileDic/diff.txt
                    log "复制双文件到 "$fileDic
                    hasJudgement=true
                    break
                fi
            done
            if [ $hasJudgement = true ];then
                continue
            fi
            hasReplace=false
            for replaceWord in "${replaceWords[@]}"
            do
                if [ `grep -c "$replaceWord" $workPath/"$file"` -ne '0' ];
                then
                    if [ ! -d $dicPath/$fileType ];
                    then
                        mkdir $dicPath/$fileType
                    fi
                    fileDic=$dicPath/$fileType/$fileName
                    if [ ! -d $fileDic ];
                    then
                        mkdir $fileDic
                    else
                        fileDic=$fileDic"_$fileNumber"
                        mkdir $fileDic
                    fi
                    log "替换文件命中替换词 "$replaceWord | tee -a $fileDic/diff.txt
                    cp $workPath/"$file" $fileDic/替换文件.$fileExtension
                    cp $localPath/"$file" $fileDic/本地文件.$fileExtension
                    echo $file | tee -a $fileDic/path.txt
                    git diff $aCommit $bCommit -- ./$file | tee -a $fileDic/diff.txt
                    log "复制双文件到 "$fileDic
                    hasReplace=true
                    break
                fi
            done
            if [ $hasReplace = true ];then
                continue
            fi
            cp $workPath/"$file" $localPath/"$file"
            log "复制文件 "$workPath/"$file"
        fi
    fi
done

