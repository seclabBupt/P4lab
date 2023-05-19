function createfigure(X1, YMatrix1)
%CREATEFIGURE(X1, YMatrix1)
%  X1:  x 数据的向量
%  YMATRIX1:  y 数据的矩阵

%  由 MATLAB 于 20-May-2023 02:30:13 自动生成

% 创建 figure
figure1 = figure('Color',[1 1 1]);

% 创建 axes
axes1 = axes('Parent',figure1);
hold(axes1,'on');

% 使用 plot 的矩阵输入创建多行
plot1 = plot(X1,YMatrix1,'MarkerSize',10,'LineWidth',2);
set(plot1(1),'DisplayName','就近调度','Marker','diamond','Color',[1 0 0]);
set(plot1(2),'DisplayName','算网融合调度','Marker','o','Color',[1 0 1]);

% 创建 ylabel
ylabel('集群负载均衡率');

% 创建 xlabel
xlabel('用户数');

% 创建 title
%title('集群负载均衡率');

% 取消以下行的注释以保留坐标区的 Y 范围
ylim(axes1,[0.4 0.9]);
box(axes1,'on');
% 设置其余坐标区属性
set(axes1,'FontWeight','bold','TitleFontWeight','bold');
% 创建 legend
legend(axes1,'show');
