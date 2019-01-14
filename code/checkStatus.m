function [ queue ] = checkStatus( time,endtime )
%checkStatus 单工序情况下检测哪些CNC已经完成了加工任务，处于等待状态
queue = [];
for i = 1:8
    if endtime(i) <= time
        queue = [queue,i];
    end
end
end

