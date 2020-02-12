```shell
if [ $# -lt 1 ]; then 
    echo "FATAL para too less, usage:"
    echo "$USAGE"
    exit 1
fi
```

 $# represents the parameter number pass into the shell 

-lt Check if the number on the left is less than the number on the right, True if it is. And in this part, the parameter pass  into the shell less than 1, it will print error information.

```shell
SHOW_CNT=0 
OPTION_TYPE=''
LOG_FILE="" # if no filename specificated, read from standard input
BLACKLIST_ON=0 
BLACKLIST_FILE="$CUR_DIR/dns.blacklist.txt" 
TMP_FILE="$CUR_DIR/tmp.txt" 
```

the SHOW_CNT will difine by the input dash n, show how much the number of lines we want to show.

OPTION_TYPE=''   is the options such as  -c, -2, -r, -F or -t

LOG_FILE="" the name of logfile

BLACKLIST_ON  check blacklist or not

BLACKLIST_FILE="$CUR_DIR/dns.blacklist.txt" define blacklist file 

TMP_FILE="$CUR_DIR/tmp.txt" # store temporary results

```shell
if [ $OPTIND -le $# ]; then
    LOG_FILE=$(eval echo "\$$OPTIND")
else
    LOG_FILE=$CUR_DIR/log
    cat "/dev/stdin" > $LOG_FILE
fi
```



```shell
if [ $SHOW_CNT -eq 0 ]; then
    SHOW_CNT=`wc -l $LOG_FILE | awk '{print $1}'`
fi
```

if the $SHOW_CNT equals to 0, then the  SHOW_CNT = number of line in LOG_FILE. 

wc -1 command counts the line in the file and awk print the number.



```shell
RESULT_LIST=""
```

set a RESULT_LIST to store the result.

```shell
if [ $OPTION_TYPE == 'c' ]; then
    echo "INFO IP address makes the most number of connection attempts:"
    RESULT_LIST=`cat $LOG_FILE | awk '{print $1}' | sort | uniq -c |sort -nr \
    | awk '{print $2","$1}' | head -$SHOW_CNT`

```

if the option type equal to 'c', then echo "INFO IP address makes the most number of connection attempts:"

cat:connect the log_file   and print to stand output and awk '{print $1}': extract ip in file, because ip is in the first space in file. sort the result and delete and count the repeat lines. And then sort by the number From big to small. And turn the order cnt\tip to ip,cnt'  print SHOW_CNT lines we want. 

```shell
elif [ $OPTION_TYPE == '2' ]; then
    echo "INFO address makes the most number of successful attempts:"
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE
    cat $LOG_FILE | egrep " 200 " | while read LINE
    do
    	IP=`echo $LINE |awk '{print $1}'`
        CODE=`echo $LINE | awk -F '"' '{print $3}' | awk '{print $1}' `
		echo "$IP" >> $TMP_FILE
    done
    RESULT_LIST=`cat $TMP_FILE | sort | uniq -c \
    |sort -nr | awk '{print $2",200"}' | head -$SHOW_CNT`
```

if the option type equal to '2', then echo "INFO address makes the most number of successful attempts:"

dash f means find the file which I specify. if it exist, I remove it. And then  create a new file called TMP_FILE.

cat the log_file connect to the file and print to stand output. egrep "200" find the lines which include "200"

and use a while loop to extract the ip and code. And sort the ip into TMP_FILE. 

And finally, output the result_list: cat the TMP_FILE connect to the file and print to stand output. And then, sort the result and delete and count the repeat lines. And then sort by the number From big to small. And then extract the ip at first and the code "200". print SHOW_CNT lines we want. 



And for the type r and f. At first, we define a "Double quotes as  delimiter to extract the result codes and delete and count the repeat lines. And then sort by the number From big to small. And then extract the code to the COMMON_CODE_LIST.	

```shell
elif [ $OPTION_TYPE == 'r' ]; then
    echo "INFO the most common results codes and where do they come from:"
    COMMON_CODE_LIST=`cat $LOG_FILE | awk -F '"' '{print $3}' \
    | awk '{print $1}' | sort | uniq -c  | sort -nr \
    | awk '{print $2}' | head -$SHOW_CNT `
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE
    for COMMON_CODE in ${COMMON_CODE_LIST}
    do
        egrep " $COMMON_CODE " $LOG_FILE |awk '{print $1}' | sort | uniq -c |sort -k 1 -n -r | awk '{print "'$COMMON_CODE',"$2}' >> $TMP_FILE
    done
    RESULT_LIST=`cat $TMP_FILE`

elif [ $OPTION_TYPE == 'F' ]; then
    echo -e "the most common result codes that indicate failure (no \c"
    echo "auth, not found etc) and where do they come from:"
    COMMON_CODE_LIST=`cat $LOG_FILE | awk -F '"' '{print $3}' | awk '{print $1}' \
    | egrep "[4-5][0-9][0-9]" |sort | uniq -c  | sort -nr | awk '{print $2}'\
    | head -$SHOW_CNT`
    if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE
    for COMMON_CODE in ${COMMON_CODE_LIST}
    do
        egrep " $COMMON_CODE " $LOG_FILE |awk '{print $1}' | sort | uniq -c |sort -k 1 -n -r | awk '{print "'$COMMON_CODE',"$2}' >> $TMP_FILE
    done
    RESULT_LIST=`cat $TMP_FILE`

```

```shell
elif [ $OPTION_TYPE == 't' ]; then
    echo "INFO IP number get the most bytes sent to them:"
	if [ -f $TMP_FILE ]; then
        rm -f $TMP_FILE
    fi
    touch $TMP_FILE
	declare -A BYTE_DICT
    BYTE_DICT=()
    while read LINE
    do
    	IP=`echo $LINE |awk '{print $1}'`
        BYTE=`echo $LINE | awk -F '"' '{print $3}' | awk '{print $2}'`
        if [ $BYTE == "-" ]; then
            continue
        fi
        if [ ! -z "${BYTE_DICT[$IP]}" ]; then
            SUM=$(( ${BYTE_DICT[$IP]} + $BYTE ))
            BYTE_DICT+=([$IP]=$SUM)
        else
            BYTE_DICT+=([$IP]=$BYTE)
        fi
    done < $LOG_FILE
    for IP in $(echo ${!BYTE_DICT[*]})
    do
        echo "$IP,${BYTE_DICT[$IP]}" >> $TMP_FILE

    done
    RESULT_LIST=`cat $TMP_FILE | sort -t $',' -k 2 -n -r | head -$SHOW_CNT`    
fi
```

if the type equal to t,   echo INFO IP number get the most bytes sent to them: 

dash f means find the file which I specify. if it exist, I remove it. And then  create a new file called TMP_FILE.

dash A declare a new array dictionary and then  initial it.

use a while loop to read all the lines in log_file, use awk command  to extract IP and BYTE. if BYTE  equal to dash, that means the BYTE is null. So we don't do any operation, just next loop. IP not exists, add it. IP already exists, update cnt. print all IP and BYTE in dictionary to the TMP_FILE .  ${!BYTE_DICT[*] print all the key value in the dictionary. dash t define the ',' as delimiter, dash k 2 is the second colunm in dictionary and dash n is number. dash r is reseverd order. And print lines we want.



```shell
declare -A BLACKLIST_DICT 
BLACKLIST_DICT=()
if [ $BLACKLIST_ON -eq 1 ]; then
	while read LINE
    do
        IP=`ping $LINE -c 1 -w 1 |egrep 'icmp_seq=1' \
        | awk -F '(' '{print $2}'  |awk -F ')' '{print $1}'`
        if [ -z $IP ]; then
            continue
        fi
        BLACKLIST_DICT+=([$IP]=1)
    done < $BLACKLIST_FILE
fi
SHOW_NUM=0
for LINE in $RESULT_LIST
do
    if [ $SHOW_CNT -ne 0 -a $SHOW_NUM -ge $SHOW_CNT ];then
        break
    fi
    IP=`echo $LINE |awk -F ',' '{print $1}'`
    CODE=`echo $LINE | awk -F ',' '{print $2}'`

    if [ ! -z "${BLACKLIST_DICT[$IP]}" ]; then
        echo -e "$IP\t$CODE\tBlacklisted"
    else
        echo -e "$IP\t$CODE"
    fi

    SHOW_NUM=$(($SHOW_NUM + 1))
done

exit 0
```

if option e is on.  ping domain only once, wait at most 1 ms.(this) icmp_sep = 1 just the select the ip include it. because there are a lot of icmp_seq. and this two awk extract the ip in result and if ip exists , go next. not, add to the  BLACKLIST_DICT.

RESULT_LIST must the rusult in the last operation. 

show num not equal to 0 and not can't more than SHOW_CNT, and we do the operation next. 

use awk command  to extract IP and code. 

if ip in blacklist, append "Blacklisted"

if not in blacklist, print ip/code.



