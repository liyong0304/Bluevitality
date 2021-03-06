###### filebeat     -->     kafka     -->     logstash     -->     Elasticsearch     -->     Kibana
#### Filebeat
```bash
filebeat:
  registry_file: .filebeat            #记录filebeat处理日志文件的位置的文件，默认在启动的根目录下
  prospectors:
    - paths:
        - /home/wangyu/Test/*.log
      input_type: log
      document_type: oslog            #输出时的document的type字段 可用来给日志进行分类 Default: log
      scan_frequency: 10s             #Every 10s scan ..
      encoding: plain
      include_lines: ["^ERR", "^WARN"]  #含正则列表的行（默认所有）include_lines执行之后会执行exclude_lines
      exclude_lines: ["^DBG"]         #要排除的行
      exclude_files: [".gz$"]         #忽略掉符合正则表达式列表的文件
      close_older: 1h                 #若文件在某个时间段内没有发生更新则关闭监控的文件handle（默认1h）
      max_bytes: 10485760             #增加1行算1个事件，max_bytes限制在1次日志事件中最多上传的字节，多出的被丢弃
      tail_files: false               #是否从文件尾部开始监控文件新增内容
      backoff: 1s                     #检测到了EOF（文件结尾）后，每次等待多久再去检测文件是否有更新，默认1s
      fields:                         #添加额外的信息
         level: debug                 #新增一个JSON的key
output.kafka: 
  enabled: true 
  hosts: ["10.0.0.3:9092"]
  topic: ES                           #MQ Topic
  partition.round_robin:
    required_acks: 1                  #Need kafka Ack
    max_message_bytes: 1000000
#output.console:
#    pretty: true
```
#### Kafka
```bash
#在Kafka的Broker端创建"Logstash"消费的主题
kafka-topics.sh --create --zookeeper 10.0.0.3:21811 --replication-factor 1 --partitions 1 --topic ES
```
#### Logstash
```bash
input{
    kafka {
        bootstrap_servers => "10.0.0.3:9092"    #Kafka Address
        group_id => "logstash"                  #要启用消费组，同组的消费者间"竞争"消费相同主题的1个消息
        topics => "ES"                          #消费主题，生产环境中可使用列表类型来订阅多个主题
        consumer_threads => 2
        decorate_events => true                 #将当前topic、offset、group、partition等信息也写入message
        auto_commit_interval_ms => 1000         #消费间隔，毫秒
        auto_offset_reset => latest             #从最后消费
        codec => "json"                         #将Filebeat传输的消息解析为JSON格式
    }
}

filter{
    grok {
        match => { 
            #Grok从message语义中按Patterns获取并分割成Key，其表达式很像C语言中的宏定义
            "message" => '%{IP:client} - \[%{DATA:time}\] "%{DATA:verb} %{DATA:url_path}
            %{DATA:httpversion}" %{NUMBER:response} %{NUMBER:} "-" \"%{DATA:agent}\"
            "-" \"%{NUMBER:request_time}\" -' 
        }
    }
    mutate{ 
        remove_field => ["tags","topic","source","version","name"]  #删除Logstash中部分不需要的"语义"Key
        add_field => [ "log_ip", "10.0.0.3" ]                       #添加指定KEY
    }
}

output{
    if [type] == "log" {
        elasticsearch {
            hosts => ["10.0.0.3:9200"]          #会根据请求体中提供的数据自动创建映射 (由Logstash端创建)
            index => "es"
            timeout => 300
            flush_size：100                     #默认500，logstash攒够500条数据再一次性向es发送
            idle_flush_time：2                  #默认1s，如果1s内没攒够500条还是会一次性将攒的数据发出去给es
        }
    }
    stdout {
        codec => "rubydebug"
    }
}

#execute ...
cd ~/logstash
nohup bin/logstash -f run-configs/demo.config \
--path.data=run.data/demo/ -l run-logs/demo/ --node.name=demo -u 200 -b 2000 &

# -u 提交间隔
# -b 每次提交的数量
# –configtest 或 -t            测试配置文件的语法
# –pipeline-workers 或 -w      运行 filter / output 的pipeline线程数，默认是CPU核数
# –pipeline-batch-size 或 -b   
# 每个pipeline线程在执行具体的filter和output前最多能累积的日志条数。默认125条。越大性能越好，但会消耗更多JVM内存
# –pipeline-batch-delay 或 -u  
# 每个pipeline线程在打包批量日志时最多等待几毫秒，默认5ms
```
#### Kibana 监控 Logstash
```bash
#在logstash/config/logstash.yml中增加如下：
#logstash把自身监控数据发送到es的index中，kibana读取该index获取数据
xpack.monitoring.enabled: true
xpack.monitoring.collection.interval: 10s
xpack.monitoring.elasticsearch.url: http://172.19.52.87:9211    #ES节点地址
http.host: "172.19.72.65"   #本机地址

```
#### Kibana ( X-pack )
```bash
xpack.monitoring.elasticsearch.url: "http://10.40.23.79:9200" 
#xpack.monitoring.elasticsearch.username: "logstash_system" 
#xpack.monitoring.elasticsearch.password: "changeme"
```
