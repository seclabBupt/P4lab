function createfigure1(xvector1, ymatrix1)
%CREATEFIGURE1(xvector1, ymatrix1)
%  XVECTOR1:  bar xvector
%  YMATRIX1:  bar 矩阵数据

%  由 MATLAB 于 20-May-2023 02:47:12 自动生成

% 创建 figure
figure1 = figure('Color',[1 1 1]);

% 创建 axes
axes1 = axes('Parent',figure1);
hold(axes1,'on');

% 使用 bar 的矩阵输入创建多行
bar1 = bar(xvector1,ymatrix1);
set(bar1(2),'DisplayName','算网融合调度');
set(bar1(1),'DisplayName','就近调度');

% 创建 ylabel
ylabel('满意用户数');

% 创建 xlabel
xlabel('用户数');

% 取消以下行的注释以保留坐标区的 Y 范围
ylim(axes1,[0 9]);
box(axes1,'on');
% 设置其余坐标区属性
set(axes1,'FontWeight','bold','TitleFontWeight','bold','XTick',[3 6 9]);
% 创建 legend
legend(axes1,'show');
