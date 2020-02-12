#!/bin/bash
#
# analyze log which ollows the unified Apache combined log format.
#
CUR_DIR=$(cd `dirname $0`; pwd) # 定义了一个CUR_DIR的变量，用 pwd 命令来查看”当前工作目录“的完整路径。 dirname脚本的父目录，$0这是bash shell脚本中的位置参数，用来表明输入到命令行中的命令本身，之后运行pwd，此时获得的就是脚本所在的绝对路径了。

USAGE="log_sum.sh [-n N] (-cI-2 I-rI-FI-tI-f) [-e]〈 filename 〉\n
-n Limit the number of results to N \n
-c Which IP address makes the most number of connection attempts? \n
-2 Which address makes the most number of successful attempts? and \n
-r What are the most common results codes where do they come from? \n 
-F: What are the most common result codes that indicate failure (no auth, \
not found etc) and where do they come from? \n
-t: Which IP number get the most bytes sent to them? \n
<filename> refers to the logfile. If is given as a filename, or no filename \
is given, then standard input should be read. This enables the script \
to be used in a pipeline. \n
-e: DNS names (related to the IPs in the log) should \
be compared with each entry in the blacklist" 

# check if parameters valid
if [ $# -lt 1 ]; then # $# represents the parameter number pass the shell and -lt Check if the number on the left is less than the number on the right, True if it is
    echo "FATAL para too less, usage:"
    echo "$USAGE"
    exit 1
fi

###############################################################################
# parse parameters
###############################################################################

SHOW_CNT=0 # option -n
OPTION_TYPE='' # option -c, -2, -r, -F or -t
LOG_FILE="" # if no filename specificated, read from standard input
BLACKLIST_ON=0 # check blacklist or not
BLACKLIST_FILE="$CUR_DIR/dns.blacklist.txt" # define blacklist file
TMP_FILE="$CUR_DIR/tmp.txt" # store temporary results

# get option leads by '-'
while getopts 'n:c2rFte' opt;
do
    case $opt in
        n)
            SHOW_CNT=$OPTARG # the number of line to output
            ;;
        c)
            OPTION_TYPE='c'
            ;;
        2)
            OPTION_TYPE='2'
            ;;
        r)
            OPTION_TYPE='r'
            ;;
        F)
            OPTION_TYPE='F'
            ;;
        t)
            OPTION_TYPE='t'
            ;;
        e)
            BLACKLIST_ON=1 
            ;;
        ?)
            ;;         
    esac   
done

# if no option chosen, error, -z check whether the specified variable has a value
if [ -z $OPTION_TYPE ]; then
    echo "FATAL para error, usage:"
    echo "$USAGE"
    exit 1
fi    

# if parameters' total count > options cnt leads by '-', 
# then log filename is given, extract it
# else get log from standard input, save to temporary file
#eval会对后面的cmdLine进行两遍扫描，如果第一遍扫描后，cmdLine是个普通命令，则执行此命令。如果cmdLine中含有变量的间接引用，则保证间接引用的语义。
#当指定了thttp的时候，log_file变量取它的名字，否则log_file变量取标准输入的名字. 相当于起了个别名 后面不用区分是不是指定文件名了，都用这个别名就行了

if [ $OPTIND -le $# ]; then
    LOG_FILE=$(eval echo "\$$OPTIND")
else
    LOG_FILE=$CUR_DIR/log
    cat "/dev/stdin" > $LOG_FILE
fi
#反引号 里面内容当作命令输出
if [ $SHOW_CNT -eq 0 ]; then
    SHOW_CNT=`wc -l $LOG_FILE | awk '{print $1}'`
fi

###############################################################################
# all parameters are parsed,
# start main process
###############################################################################

# get result list
# format: ip, cnt/code
RESULT_LIST=""
if [ $OPTION_TYPE == 'c' ]; then
    echo "INFO IP address makes the most number of connection attempts:"

    # store to variable
    # cat connect to the file and print to stand output
    # awk '{print $1}': extract ip in file, because ip is in the first space in file. 
    # sort: order ip by alphabet ordering
    # uniq -c: calculate ip's cnt, output format: 'cnt\tip' 删除重复行后并计数 
    # sort -nr: ordered by cnt reverse
    # awk: convert output format, 'cnt\tip'->'ip,cnt'
    # | command 1 | command 2 他的功能是把第一个命令command 1执行的结果作为command 2的输入传给command 2
    RESULT_LIST=`cat $LOG_FILE | awk '{print $1}' | sort | uniq -c |sort -nr \
    | awk '{print $2","$1}' | head -$SHOW_CNT`

elif [ $OPTION_TYPE == '2' ]; then
    echo "INFO address makes the most number of successful attempts:"
 
    # create temp file, if already exists, remove it first
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    #可以使用touch命令来轻松创建空文件 use touch to create a  new TMP_FILE file
    touch $TMP_FILE

    # process each line, get ip with most succesfull attempts
    # egrep: keep code 200 only
    cat $LOG_FILE | egrep " 200 " | while read LINE
    do
        # awk: extract ip and code
        # since field total cnt are diverse, use different separators: 
        # space and quote        
        IP=`echo $LINE |awk '{print $1}'`
        CODE=`echo $LINE | awk -F '"' '{print $3}' | awk '{print $1}' `

        # import into temp file
        echo "$IP" >> $TMP_FILE
    done

    # store to variable
    # 
    # sort: order ip by alphabet ordering
    # uniq -c: calculate ip's cnt, output format: 'cnt\tip' 删除重复行后并计数 
    # sort -nr: ordered by cnt reverse
    # awk: convert output format, 'cnt\tip'->'ip,code' 
    #head 使用head打印文件的前...行

    RESULT_LIST=`cat $TMP_FILE | sort | uniq -c \
    |sort -nr | awk '{print $2",200"}' | head -$SHOW_CNT`

elif [ $OPTION_TYPE == 'r' ]; then
    echo "INFO the most common results codes and where do they come from:"

    # get the most common results codes
    # | awk -F '"' '{print $3}' \| awk '{print $1}':  它这个操作输出的是第三个' “ ‘的 内容，然后在这个内容的基础上输出code
    # sort: order code alphabet ordering
    # uniq -c: calculate code's cnt, output format: 'cnt\tcode'
    # sort -nr: ordered by cnt reverse
    # awk: extract codes only
    #head 使用head打印文件的前...行
    COMMON_CODE_LIST=`cat $LOG_FILE | awk -F '"' '{print $3}' \
    | awk '{print $1}' | sort | uniq -c  | sort -nr \
    | awk '{print $2}' | head -$SHOW_CNT `

    # create temp file, if already exists, remove it first
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE

    # extract the most common codes' ip
    # egrep " $COMMON_CODE " find the lines which include " $COMMON_CODE "
    # extract the most common codes' ip
    # Linux grep 命令Linux 命令大全Linux grep 命令用于查找文件里符合条件的字符串。 grep 指令用于查找内容包含指定的范本样式的文件，如果发现某文件的内容符合
    #awk '{print $1",'$COMMON_CODE'"}' 是 IP+code
    for COMMON_CODE in ${COMMON_CODE_LIST}
    do
        egrep " $COMMON_CODE " $LOG_FILE |awk '{print $1}' | sort | uniq -c |sort -k 1 -n -r | awk '{print "'$COMMON_CODE',"$2}' >> $TMP_FILE
    done

    # store to variable
    RESULT_LIST=`cat $TMP_FILE`

elif [ $OPTION_TYPE == 'F' ]; then
    echo -e "the most common result codes that indicate failure (no \c"
    echo "auth, not found etc) and where do they come from:"

    # get the most common results codes that indicate failure(not 200~300)
    # awk: extract code
    # grep: keep code not 200
    # sort: order code alphabet ordering
    # uniq -c: calculate code's cnt, output format: 'cnt\tcode'
    # sort -nr: ordered by cnt reverse
    # awk: extract codes only
    COMMON_CODE_LIST=`cat $LOG_FILE | awk -F '"' '{print $3}' | awk '{print $1}' \
    | egrep "[4-5][0-9][0-9]" |sort | uniq -c  | sort -nr | awk '{print $2}'\
    | head -$SHOW_CNT`

    # create temp file, if already exists, remove it first
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE

    # extract the most common codes' ip
    for COMMON_CODE in ${COMMON_CODE_LIST}
    do
        egrep " $COMMON_CODE " $LOG_FILE |awk '{print $1}' | sort | uniq -c |sort -k 1 -n -r | awk '{print "'$COMMON_CODE',"$2}' >> $TMP_FILE
    done

    # store to variable
    RESULT_LIST=`cat $TMP_FILE`

elif [ $OPTION_TYPE == 't' ]; then
    echo "INFO IP number get the most bytes sent to them:"

    # create temp file, if already exists, remove it first
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE

    # declare dict
    declare -A BYTE_DICT
    BYTE_DICT=()

    while read LINE #read通过输入重定向，把file的第一行所有的内容赋值给变量line，循环体内的命令一般包含对变量line的处理；然后循环处理file的第二行、第三行。。。一直到file的最后一行。
        # awk: extract ip and code
        # since field total cnt are diverse, use different separators: 
        # space and quote       
        IP=`echo $LINE |awk '{print $1}'`
        BYTE=`echo $LINE | awk -F '"' '{print $3}' | awk '{print $2}'`
        
        # byte empty
        if [ $BYTE == "-" ]; then
            continue
        fi
        # operate dict  
        #打印指定key的value
        #echo ${dic["key1"]}
        #打印所有key值
        #echo ${!dic[*]}
        #打印所有value
        #echo ${dic[*]}
        #字典添加一个新元素
        #dic+=（[key4]="value4"）
        # operate dict 从else 往前看。
        #－z：判断制定的变量是否存在值。 ！存在false，！不存在是true。
        if [ ! -z "${BYTE_DICT[$IP]}" ]; then
            # IP already exists, update cnt
            SUM=$(( ${BYTE_DICT[$IP]} + $BYTE ))
            BYTE_DICT+=([$IP]=$SUM)
        else
            # IP not exists, add it
            BYTE_DICT+=([$IP]=$BYTE)
        fi
    done < $LOG_FILE

    # import into temp file
    for IP in $(echo ${!BYTE_DICT[*]})
    do
        echo "$IP,${BYTE_DICT[$IP]}" >> $TMP_FILE

    done

    # store to variable
    #
    # sort: -t define separator
    #       -k order by column 2
    #       -n treat as number
    #       -r sort verse
    RESULT_LIST=`cat $TMP_FILE | sort -t $',' -k 2 -n -r | head -$SHOW_CNT`    
fi

###############################################################################
# output results
# check if in blacklist
# reduce output cnt
###############################################################################

# load dns blacklist into dict
declare -A BLACKLIST_DICT #bash版本在4.0以上可以使用
BLACKLIST_DICT=()

# if option e is on
if [ $BLACKLIST_ON -eq 1 ]; then
    # read blacklist
    while read LINE
    do
        # ping domain only once, wait at most 1 ms
        #icmp_sep = 1 just the select we ping in 1 second because there are a lot of icmp_seq
        # and this two awk extract the ip in result and 
        IP=`ping $LINE -c 1 -w 1 |egrep 'icmp_seq=1' \
        | awk -F '(' '{print $2}'  |awk -F ')' '{print $1}'`
        if [ -z $IP ]; then
            continue
        fi
        # save domain's ip to dict
        BLACKLIST_DICT+=([$IP]=1)

    done < $BLACKLIST_FILE
fi

# output top result limited by option n
# 怪不得 配合一个参数使用，不然RESULT_LIST怎么来呢
SHOW_NUM=0
for LINE in $RESULT_LIST
do
    # get top result. if option n not given, output all results
    #-a and
    #-ne 0 not equal to 0
    #-ge left number more than right number, true if it is.
     # get top result. if option n not given, output all results
    # -ne 检测两个数是否不相等，不相等返回 true。
    # -a 与运算，两个表达式都为 true 才返回 true。 
    # -ge 检测左边的数是否大于等于右边的，如果是，则返回 true。
    if [ $SHOW_CNT -ne 0 -a $SHOW_NUM -ge $SHOW_CNT ];then
        break
    fi

    # DNS names compared with each entry in the blacklist
    IP=`echo $LINE |awk -F ',' '{print $1}'`
    CODE=`echo $LINE | awk -F ',' '{print $2}'`

    #-e 开启转义。
    #\t 换行
    if [ ! -z "${BLACKLIST_DICT[$IP]}" ]; then
        # if ip in blacklist, append "Blacklisted"
        echo -e "$IP\t$CODE\tBlacklisted"
    else
        echo -e "$IP\t$CODE"
    fi

    SHOW_NUM=$(($SHOW_NUM + 1)) #控制循环的吧
done

exit 0
