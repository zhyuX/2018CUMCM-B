function [ num, order] = getAssign( time1,time2 )
%getAssign 根据工序1、工序2的时间，计算合适的分配比例并给出工序一CNC所有的排列组合
num = 4;
loss = 99999;
order = [];
for i = 1:7
    if abs(i/time1 - (8-i)/time2) < loss
        loss = abs(i/time1 - (8-i)/time2);
        num = i;
    end
end
% 生成排列
temp = nchoosek(1:8, num);
for i = 1:length(temp)
    order = [order; perms(temp(i,:))];
end
end

