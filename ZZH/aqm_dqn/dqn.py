import gym
from gym import spaces
import numpy as np
import torch
import random
import math
import subprocess
import time

Queue = 50
Por = 50
Epoch=0

def extract_data_from_line(line):
    # 检查行的格式是否正确
    if line.startswith("Received packet - Queue:"):
        # 解析行并提取数据
        parts = line.split(', ')
        try:
            queue = int(parts[0].split(': ')[-1])
            delay = int(parts[1].split(': ')[-1])
            timecha = int(parts[2].split(': ')[-1])
            return queue, delay, timecha
        except ValueError as e:
            print(f"Error extracting data: {e}")
    else:
        print(f"Invalid line format: {line}")
    return None


def read_last_line(file_path):
    try:
        with open(file_path, 'r') as file:
            lines = file.readlines()
            if lines:
                last_line = lines[-1].strip()
                return last_line
    except FileNotFoundError:
        print(f"File '{file_path}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")


def move(action):
    global Queue,Por
    if action == 0:
        return Queue, Por

    if action == 1:
        Queue = Queue * 0.8

    if action == 2:
        Por = Por * 0.8

    if action == 3:
        Queue = Queue * 1.2

    if action == 4:
        Por = Por * 1.2

    Queue=max(12,Queue)
    Queue=min(100,Queue)
    Por=max(1,Por)
    Por=min(100,Por)
    return Queue, Por

def chushi_xiabiao():
    command = f"docker exec -it kathara_root-mrzg3d6w93xvsgji2owglq_re_s1_mcNRhGYJfBwssmSbZGDPbA python3 xiabiao.py 50 50"
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, universal_newlines=True)
def xiabiao(action):
    queue, por = move(action)
    command = f"docker exec -it kathara_root-mrzg3d6w93xvsgji2owglq_re_s1_mcNRhGYJfBwssmSbZGDPbA python3 xiabiao.py {queue} {por}"
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, universal_newlines=True)
    #print(queue,por)


# 文件路径
file_path = 'a'


class CustomEnv(gym.Env):
    def __init__(self):
        super(CustomEnv, self).__init__()

        self.state_space_dim = 4
        self.action_space_dim = 5

        # 定义状态空间和动作空间
        # self.observation_space = spaces.Box(low=0, high=1, shape=(self.state_space_dim,), dtype=np.float32)
        self.action_space = spaces.Discrete(self.action_space_dim)

        self.step_n = 0

        # 初始化环境状态
        last_line = read_last_line(file_path)
        if last_line:
            # 提取数据
            data = extract_data_from_line(last_line)
            if data is not None:
                queue, delay, timecha = data
        panjue = 2500
        self.state = np.array([queue, delay, timecha, panjue])

    def reset(self):
        # 重置环境
        global Queue,Por
        Queue = 50
        Por = 50
        chushi_xiabiao()
        time.sleep(1)

        last_line = read_last_line(file_path)
        if last_line:
            # 提取数据
            data = extract_data_from_line(last_line)
            if data is not None:
                queue, delay, timecha = data
        panjue = 2500
        self.state = np.array([queue, delay, timecha, panjue])
        self.step_n = 0
        return self.state

    def step(self, action):
        # 执行动作并返回新的状态、奖励和完成标志
        last_line = read_last_line(file_path)
        if last_line:
            # 提取数据
            data = extract_data_from_line(last_line)
            if data is not None:
                queue, delay, timecha = data
        panjue = Queue * Por
        self.state = np.array([queue, delay, timecha, panjue])
        reward = self._calculate_reward(delay, timecha)
        done = False
        self.step_n += 1
        if self.step_n>=32:
            done=True
        return self.state, reward, done, {}

    def _calculate_reward(self, delay, timecha):
        # 根据动作计算奖励
        #return -0.8 * math.log(abs(delay - 5000)) - 0.2 * math.log(timecha)
        return -0.8*(abs(delay - 5000))/100-0.2*timecha/100


# 创建环境实例
env = CustomEnv()

'''
# 测试环境
observation = env.reset()
done = False

while not done:
    action = env.action_space.sample()  # 随机选择动作
    observation, reward, done, _ = env.step(action)
    print(f"Action: {action}, Reward: {reward}, Done: {done}, Observation: {observation}")

# 关闭环境
env.close()
'''

model = torch.nn.Sequential(
    torch.nn.Linear(4, 128),
    torch.nn.ReLU(),
    torch.nn.Linear(128, 5),
)

# 经验网络,用于评估一个状态的分数
next_model = torch.nn.Sequential(
    torch.nn.Linear(4, 128),
    torch.nn.ReLU(),
    torch.nn.Linear(128, 5),
)

# 把model的参数复制给next_model
next_model.load_state_dict(model.state_dict())


def get_action(state):
    global Epoch

    if random.random() < 0.01*(100-2*Epoch):
        return random.choice([0, 4])

    # 走神经网络,得到一个动作
    state = torch.FloatTensor(state).reshape(1, 4)

    return model(state).argmax().item()


datas = []


# 向样本池中添加N条数据,删除M条最古老的数据
def update_data():
    old_count = len(datas)
    # 玩到新增了N个数据为止

    while len(datas) - old_count < 32:
        # 初始化游戏
        state = env.reset()

        # 玩到游戏结束为止
        over = False
        while not over:
        # 根据当前状态得到一个动作
            action = get_action(state)
            xiabiao(action)
            time.sleep(1)

        # 执行动作,得到反馈
            next_state, reward, over, _ = env.step(action)

        # 记录数据样本
            datas.append((state, action, reward, next_state, over))

        # 更新游戏状态,开始下一个动作
            state = next_state


    update_count = len(datas) - old_count
    drop_count = max(len(datas) - 300, 0)

    # 数据上限,超出时从最古老的开始删除
    while len(datas) > 300:
        datas.pop(0)

    return update_count, drop_count


def get_sample():
    # 从样本池中采样
    samples = random.sample(datas, 32)

    # [b, 4]
    state = torch.FloatTensor([i[0] for i in samples]).reshape(-1, 4)
    # [b, 1]
    action = torch.LongTensor([i[1] for i in samples]).reshape(-1, 1)
    # [b, 1]
    reward = torch.FloatTensor([i[2] for i in samples]).reshape(-1, 1)
    # [b, 4]
    next_state = torch.FloatTensor([i[3] for i in samples]).reshape(-1, 4)
    # [b, 1]
    over = torch.LongTensor([i[4] for i in samples]).reshape(-1, 1)

    return state, action, reward, next_state, over


def get_value(state, action):
    # 使用状态计算出动作的logits
    # [b, 4] -> [b, 2]
    value = model(state)

    # 根据实际使用的action取出每一个值
    # 这个值就是模型评估的在该状态下,执行动作的分数
    # 在执行动作前,显然并不知道会得到的反馈和next_state
    # 所以这里不能也不需要考虑next_state和reward
    # [b, 2] -> [b, 1]
    value = value.gather(dim=1, index=action)

    return value


def get_target(reward, next_state, over):
    # 上面已经把模型认为的状态下执行动作的分数给评估出来了
    # 下面使用next_state和reward计算真实的分数
    # 针对一个状态,它到底应该多少分,可以使用以往模型积累的经验评估
    # 这也是没办法的办法,因为显然没有精确解,这里使用延迟更新的next_model评估

    # 使用next_state计算下一个状态的分数
    # [b, 4] -> [b, 2]
    with torch.no_grad():
        target = next_model(next_state)

    # 取所有动作中分数最大的
    # [b, 2] -> [b, 1]
    target = target.max(dim=1)[0]
    target = target.reshape(-1, 1)

    # 下一个状态的分数乘以一个系数,相当于权重
    target *= 0.98

    # 如果next_state已经游戏结束,则next_state的分数是0
    # 因为如果下一步已经游戏结束,显然不需要再继续玩下去,也就不需要考虑next_state了.
    # [b, 1] * [b, 1] -> [b, 1]
    target *= (1 - over)

    # 加上reward就是最终的分数
    # [b, 1] + [b, 1] -> [b, 1]
    target += reward

    return target


def test():
    # 初始化游戏
    state = env.reset()

    # 记录反馈值的和,这个值越大越好
    reward_sum = 0

    # 玩到游戏结束为止
    over = False
    while not over:
    # 根据当前状态得到一个动作
        action = get_action(state)
        xiabiao(action)
        time.sleep(1)

    # 执行动作,得到反馈
        state, reward, over, _ = env.step(action)
        reward_sum += reward


    return reward_sum


def train():
    model.train()
    optimizer = torch.optim.Adam(model.parameters(), lr=2e-3)
    loss_fn = torch.nn.MSELoss()
    # 训练N次

    for epoch in range(500):
        # 更新N条数据
        update_count, drop_count = update_data()
        global Epoch
        Epoch=epoch

        # 每次更新过数据后,学习N次
        for i in range(20):
            # 采样一批数据
            state, action, reward, next_state, over = get_sample()

            # 计算一批样本的value和target
            value = get_value(state, action)
            target = get_target(reward, next_state, over)

            # 更新参数
            loss = loss_fn(value, target)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            # 把model的参数复制给next_model
            if (i + 1) % 10 == 0:
                next_model.load_state_dict(model.state_dict())

        test_result = test()
        print(epoch+1, Queue,Por,test_result)



train()
