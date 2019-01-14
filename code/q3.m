% 模拟故障状态，随机选择一台CNC发生故障（故障时刻随机，检修时长在范围内随机）
breakdown_idx = unidrnd(8);
breakdown_start = unidrnd(8*60*60);
breakdown_end = breakdown_start + 10*60 + unidrnd(10*60);
fprintf('故障的是%d号,%d -- %d\n',breakdown_idx,breakdown_start,breakdown_end);
% 常量
cnc_pos = [1 1 2 2 3 3 4 4]; % 每个CNC对应的轨道位置
tmove = [23 41 59]; % RGV移动时间*
tprocess = 560; % CNC加工一道工序时间*
tud = repmat([28 31],1,4); % 各CNC上下料所需时间*
tclean = 25; % 清洗时间*
TARGET = 400; % 目标加工件数

order = [1 3 5 7 8 6 4 2];
% 变量
queue = []; % 等待指令队列
current_pos = 1; % RGV小车的位置 1/2/3/4
cnc_now = [0 0 0 0 0 0 0 0]; % CNC当前加工的物料号，初始置0
cnc_endtime = [0 0 0 0 0 0 0 0]; % CNC当前加工物料的结束时间，初始置0
cnt = 0; % 当前加工件数
cnt_finish = 0; % 完全加工的数量
time = 0; % 当前所用时间
% 求解结果矩阵（对应excle表格）
result = zeros(TARGET,4);  % 物料号/CNC号/上料开始时刻/下料开始时刻


% 计算走完第一轮的时间(秒）
for i = 1:8
    pos = cnc_pos(order(i));
    % （移动）+ 上料
    if pos == current_pos % 无需移动，直接上料
        result(i,1) = i;
        result(i,2) = order(i);
        result(i,3) = time;
        time = time + tud(order(i)); % 上料时间消耗
        cnc_endtime(order(i)) = time + tprocess; % 记录该cnc结束加工的时间
        cnc_now(order(i)) = i; % 记录该cnc当前加工的物料号

    else % 先移动，后上料
        distance = abs(pos - current_pos);
        time = time + tmove(distance); % 移动时间消耗
        result(i,1) = i;
        result(i,2) = order(i);
        result(i,3) = time;
        time = time + tud(order(i)); 
        cnc_endtime(order(i)) = time + tprocess;
        cnc_now(order(i)) = i;
        
    end
    current_pos = pos; % 更新当前位置
end

cnt = 8;
breakdown_flag = 1; % 哨兵变量 控制恢复结束时间的操作 只执行一次
complete_flag = 1; % 哨兵变量 控制”故障时是否处于加工状态“的检测只进行一次
is_compelete = 0;

while cnt_finish < TARGET
    if time >= breakdown_start && time <= breakdown_end
        if cnc_endtime(breakdown_idx) <= breakdown_start && complete_flag == 1% 判断是否完成
            is_compelete = 1;
            complete_flag = 0;
        end
        if is_compelete == 0
            cnc_now(breakdown_idx) = 0; % 报废了
        end 
            cnc_endtime(breakdown_idx) = 99999; %故障期间给结束时间置一个巨大的值，故障结束恢复
    elseif time >= breakdown_end % 恢复结束时间 该操作只执行一次
        if breakdown_flag == 1
            cnc_endtime(breakdown_idx) = time;
            breakdown_flag = 0;
        end
    end
    if time <  min(cnc_endtime)
        time = min(cnc_endtime); % 如果所有CNC都处于加工状态,时间“快进”
        continue;
    else
        queue = checkStatus( time,cnc_endtime );
        
        assert(isempty(queue)==0, '队列为空！')
        % 最近距离先服务
        [idx, dis] = getClosest( current_pos, queue ); % 计算RGV的下一个CNC目标idx 及距离
        if dis > 0
            time = time + tmove(dis); % 如果需要移动，加上移动的时间
            current_pos = cnc_pos(idx); % 移动
        end
        % 上/下料
        temp = cnc_now(idx); % 获取物料序号
        if temp == 0 % 之前加工了一半故障的，只需要上料，不用清洗和记录下料
            cnt = cnt + 1; % 新的物料上料加工
            result(cnt,1) = cnt;
            result(cnt,2) = idx;
            result(cnt,3) = time; % 记录新物料上料开始时间
            time = time + tud(idx); % 上料时间消耗
            cnc_now(idx) = cnt; %更新加工物料序号
            cnc_endtime(idx) = time + tprocess; % 更新加工完成时间
        else
            result(temp,4) = time; % 记录下料开始时间
            cnt = cnt + 1; % 新的物料上料加工
            result(cnt,1) = cnt;
            result(cnt,2) = idx;
            result(cnt,3) = time; % 记录新物料上料开始时间
            time = time + tud(idx); % 下料时间消耗
            cnc_now(idx) = cnt; %更新加工物料序号
            cnc_endtime(idx) = time + tprocess; % 更新加工完成时间

            time = time + tclean; % 清洗时间消耗
            cnt_finish = cnt_finish + 1;
        end
    end
end
