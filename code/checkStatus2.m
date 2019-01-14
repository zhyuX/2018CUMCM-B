function [ queue1,queue2 ] = checkStatus2( time,endtime,assign )
%checkStatus2 模型双工序情境下检测哪些CNC已经完成了加工任务，处于等待状态
%   queue1表示工序1CNC等待队列，queue2表示工序2CNC等待队列
queue1 = [];
queue2 = [];
for i = 1:8
    if endtime(i) <= time
        if assign(i)==1
            queue1 = [queue1,i];
        else
            queue2 = [queue2,i];
        end
    end
end
end