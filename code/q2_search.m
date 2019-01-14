% 常量
cnc_pos = [1 1 2 2 3 3 4 4]; % 每个CNC对应的轨道位置
tmove = [20 33 46]; % RGV移动时间*
tprocess1 = 400; % CNC加工第1道工序用时*
tprocess2 = 378; % CNC加工第2道工序用时*
tud = repmat([28 31],1,4); % 各CNC上下料所需时间*
tclean = 25; % 清洗时间*
TARGET = 300; % 目标加工件数
[num,order1] = getAssign(tprocess1,tprocess2); % 工序1的CNC序列

for j = 1:length(order1)
% 变量
queue1 = []; % 工序1等待指令队列
queue2 = []; % 工序2等待指令队列
current_pos = 1; % RGV小车的位置 1/2/3/4
cnc_now = [0 0 0 0 0 0 0 0]; % CNC当前加工的物料号，初始置0
cnc_endtime = [0 0 0 0 0 0 0 0]; % CNC当前加工物料的结束时间，初始置0
cnc_assign = [2 2 2 2 2 2 2 2]; % CNC负责的工序
cnt = 0; % 当前加工件数
cnt_finish = 0; % 完全加工的数量
time = 0; % 当前所用时间
result = zeros(TARGET,7);  % 1物料号/2工序1CNC号/3上料开始/4下料开始/5工序2CNC号/6上料开始/7下料开始

% 根据工序1的初始顺序 更新cnc_assign
for i = 1:num
    cnc_assign(order1(j,i)) = 1;
end

% 按顺序给每台负责工序1的CNC上料
for i = 1:num
    pos = cnc_pos(order1(j,i)); % 获取目标的位置
    % （移动）+ 上料
    if pos == current_pos % 无需移动，直接上料
        result(i,1) = i;
        result(i,2) = order1(j,i);
        result(i,3) = time; % 记录上料开始的时刻
        time = time + tud(order1(j,i)); % 上料时间消耗
        cnc_endtime(order1(j,i)) = time + tprocess1; % 记录该cnc结束加工的时间
        cnc_now(order1(j,i)) = i; % 记录该cnc当前加工的物料号
    
    else
        distance = abs(pos - current_pos);
        time = time + tmove(distance); % 移动时间消耗
        result(i,1) = i;
        result(i,2) = order1(j,i);
        result(i,3) = time;
        time = time + tud(order1(j,i)); 
        cnc_endtime(order1(j,i)) = time + tprocess1;
        cnc_now(order1(j,i)) = i;
    end
    current_pos = pos; % 更新当前位置
end

cnt = num;
flag = 1; % RGV下一个执行的工序（1、2交替）
hold = 1; % RGV所持半成品的序号（只完成了工序一）

while cnt_finish < TARGET
    if time <  min(cnc_endtime(cnc_assign==flag))
        time = min(cnc_endtime(cnc_assign==flag)); % 如果所有CNC都处于加工状态,时间“快进”
        continue;
    else
        [queue1, queue2] = checkStatus2(time,cnc_endtime,cnc_assign); % 更新两个等待队列
        if flag == 1 % 若下一个执行的工序为1
            assert(isempty(queue1)==0, '队列1为空！')
            % 按最近距离先服务原则 前往目标执行上下料操作
            [idx, dis] = getClosest( current_pos, queue1 ); % 计算RGV的下个CNC（工序二）目标idx 及距离
            if dis > 0
                time = time + tmove(dis); % 如果需要移动，加上移动的时间
                current_pos = cnc_pos(idx); % 移动
            end
            % 开始 下/上料操作
            temp = cnc_now(idx); % 获取物料序号
            result(temp,4) = time; % 记录工序1下料开始时间
            cnt = cnt + 1; % 取一个新的生料
            result(cnt,1) = cnt;
            result(cnt,2) = idx;
            result(cnt,3) = time;
            time = time + tud(idx); % 上下料操作时间消耗
            cnc_now(idx) = cnt; %更新加工物料序号
            cnc_endtime(idx) = time + tprocess1; % 更新加工完成时间
            hold = temp; % 记录半成品的序号
            flag = 2; % 调整下一个执行工序为2
            
        else % 若下一个执行的工序为2
            assert(isempty(queue2)==0, '队列2为空！')
            % 按最近距离先服务原则 前往目标执行上下料操作
            [idx, dis] = getClosest( current_pos, queue2 ); % 计算RGV的下个CNC（工序二）目标idx 及距离
            if dis > 0
                time = time + tmove(dis); % 如果需要移动，加上移动的时间
                current_pos = cnc_pos(idx); % 移动
            end
            % 移动完毕，开始下/上料
            if cnc_now(idx) > 0 % 台子上有东西（即第一轮以后的情况）
                temp = cnc_now(idx); % 获取物料序号
                result(temp,7) = time; % 记录工序2下料开始时间
                sp = 1; % 标记台子上有东西
            else
                sp = 0;
            end
            result(hold,5) = idx;
            result(hold,6) = time;
            time = time + tud(idx); % 上下料操作时间消耗
            cnc_now(idx) = hold; %更新加工物料序号
            cnc_endtime(idx) = time + tprocess2; % 更新加工完成时间
            if sp == 1 % 台子上有东西（即第一轮以后的情况）
                time = time + tclean; % 清洗时间消耗
                cnt_finish = cnt_finish + 1;
            end
            flag = 1; % 调整下一个执行工序为2
        end
    end
end
order1(j,num+1) = result(TARGET-10,7); %记录每种排列对应的完成耗时(-10是为了避免目标物料未下料导致的错误）
end
[row,column]=find(order1==min(order1(:,num+1)));
bestorder = order1(row,:); % 找出最优的组合