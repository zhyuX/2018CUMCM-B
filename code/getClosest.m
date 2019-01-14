function [ closeIdx, min ] = getClosest( pos, queue )
%getClosest 找到队列中距离当前位置最近的序号 返回序号和距离
closeIdx = -1;
min = 5;
num = length(queue);
for i = 1:num
    if abs(ceil(queue(i)/2) - pos) < min
        min =  abs(ceil(queue(i)/2) - pos);
        closeIdx = queue(i);
    end
end

end

