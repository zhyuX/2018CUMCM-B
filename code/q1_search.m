% 常量(某组参数）
cnc_pos = [1 1 2 2 3 3 4 4]; % 每个CNC对应的轨道位置
tmove = [18 32 46]; % RGV移动时间*
tprocess = 545; % CNC加工一道工序时间*
tud = repmat([27 32],1,4); % 各CNC上下料所需时间*
tclean = 25; % 清洗时间*
TARGET = 400; % 目标加工件数

order = perms(1:8); %生成所有排列组合

for j = 1:length(order)

% 变量
queue = []; % 等待指令队列
current_pos = 1; % RGV小车的位置 1/2/3/4
cnc_now = [0 0 0 0 0 0 0 0]; % CNC当前加工的物料号，初始置0
cnc_endtime = [0 0 0 0 0 0 0 0]; % CNC当前加工物料的结束时间，初始置0
cnt = 0; % 当前加工件数
cnt_finish = 0; % 完全加工的数量
time = 0; % 当前所用时间
result = zeros(TARGET,4);  % 存放结果：物料号/CNC号/上料开始时刻/下料开始时刻


% 计算走完第一轮的时间(秒）
for i = 1:8
    pos = cnc_pos(order(j,i));
    % （移动）+ 上料
    if pos == current_pos % 无需移动，直接上料
        result(i,1) = i;
        result(i,2) = order(j,i);
        result(i,3) = time;
        time = time + tud(order(j,i)); % 上料时间消耗
        cnc_endtime(order(j,i)) = time + tprocess; % 记录该cnc结束加工的时间
        cnc_now(order(j,i)) = i; % 记录该cnc当前加工的物料号
        
    else % 先移动，后上料
        distance = abs(pos - current_pos);
        time = time + tmove(distance); % 移动时间消耗
        result(i,1) = i;
        result(i,2) = order(j,i);
        result(i,3) = time;
        time = time + tud(order(j,i)); 
        cnc_endtime(order(j,i)) = time + tprocess;
        cnc_now(order(j,i)) = i;
    end
    current_pos = pos; % 更新当前位置
end

cnt = 8;

while cnt_finish < TARGET
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
order(j,9) = result(TARGET,4);
if mod(j,4000)==0
    fprintf('%d\n',j);
end
end
[row,column]=find(order==min(order(:,9))); % 寻找最优的那（些）组参数
% order(row,:) 
