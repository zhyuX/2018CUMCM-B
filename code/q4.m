% 模拟故障状态，随机选择一台CNC发生故障（故障时刻随机，检修时长在范围内随机）
breakdown_idx = unidrnd(8);
breakdown_start = unidrnd(8*60*60);
breakdown_end = breakdown_start + 10*60 + unidrnd(10*60);
fprintf('故障的是%d号,%d -- %d\n',breakdown_idx,breakdown_start,breakdown_end);
% 常量
cnc_pos = [1 1 2 2 3 3 4 4]; % 每个CNC对应的轨道位置
tmove = [18 32 46]; % RGV移动时间*
tprocess1 = 455; % CNC加工第1道工序用时*
tprocess2 = 182; % CNC加工第2道工序用时*
tud = repmat([27 32],1,4); % 各CNC上下料所需时间*
tclean = 25; % 清洗时间*
TARGET = 300; % 目标加工件数

order1 = [1 8 4 7 6 2]; % 工序1的CNC序列

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
% 求解结果矩阵（对应excle表格）
result = zeros(TARGET,7);  % 1物料号/2工序1CNC号/3上料开始/4下料开始/5工序2CNC号/6上料开始/7下料开始

% 根据工序1的初始顺序 更新cnc_assign
for i = 1:length(order1)
    cnc_assign(order1(i)) = 1;
end

% 按顺序给每台负责工序1的CNC上料
for i = 1:length(order1)
    pos = cnc_pos(order1(i)); % 获取目标的位置
    % （移动）+ 上料
    if pos == current_pos % 无需移动，直接上料
        result(i,1) = i;
        result(i,2) = order1(i);
        result(i,3) = time; % 记录上料开始的时刻
        time = time + tud(order1(i)); % 上料时间消耗
        cnc_endtime(order1(i)) = time + tprocess1; % 记录该cnc结束加工的时间
        cnc_now(order1(i)) = i; % 记录该cnc当前加工的物料号
    
    else
        distance = abs(pos - current_pos);
        time = time + tmove(distance); % 移动时间消耗
        result(i,1) = i;
        result(i,2) = order1(i);
        result(i,3) = time;
        time = time + tud(order1(i)); 
        cnc_endtime(order1(i)) = time + tprocess1;
        cnc_now(order1(i)) = i;
    end
    current_pos = pos; % 更新当前位置
end

cnt = length(order1);
flag = 1; % RGV下一个执行的工序（1、2交替）
hold = 1; % RGV所持半成品的序号（只完成了工序一）

breakdown_flag = 1; % 哨兵变量 控制恢复结束时间的操作 只执行一次
complete_flag = 1; % 哨兵变量 控制”故障时是否处于加工状态“的检测只进行一次
is_compelete = 0;

while cnt_finish < TARGET
    if time >= breakdown_start && time <= breakdown_end
        if cnc_endtime(breakdown_idx) <= breakdown_start && complete_flag == 1% 判断是否完成(仅判断一次）
            is_compelete = 1;
            complete_flag = 0;
        end
        if is_compelete == 0
            cnc_now(breakdown_idx) = 0; % 报废了
        end 
            cnc_endtime(breakdown_idx) = 99999;
    elseif time >= breakdown_end % 只执行一次
        if breakdown_flag == 1
            cnc_endtime(breakdown_idx) = time;
            breakdown_flag = 0;
        end
    end
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
            if temp == 0 % CNC台子是空的
                cnt = cnt + 1; % 取一个新的生料
                result(cnt,1) = cnt;
                result(cnt,2) = idx;
                result(cnt,3) = time;
                time = time + tud(idx); % 上下料操作时间消耗
                cnc_now(idx) = cnt; %更新加工物料序号
                cnc_endtime(idx) = time + tprocess1; % 更新加工完成时间
                flag = 1;
            else
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
            end
            
            
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
            cnc_now(idx) = hold; %更新加工物料序号
            time = time + tud(idx); % 上下料操作时间消耗
            cnc_endtime(idx) = time + tprocess2; % 更新加工完成时间
            if sp == 1 % 台子上有东西（即第一轮以后的情况）
                time = time + tclean; % 清洗时间消耗
                cnt_finish = cnt_finish + 1;
            end
            flag = 1; % 调整下一个执行工序为1
        end
        
    end
end