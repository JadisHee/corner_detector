clear all;
clc;
% 输入彩色图像
I = imread('image/4.jpg');
% 将图像转化为灰度
f = rgb2gray(I);
% f = checkerboard(50,3,3);

% 设置影响因子
k = 0.04;
% 设置阈值系数
q = 0.01;
% 设置尺度大小为sobel核来对图像像素点进行第一次滤波
fn = [2,1,0,-1,-2;
      2,1,0,-1,-2;
      4,2,0,-2,-4;
      2,1,0,-1,-2;
      2,1,0,-1,-2];
fx = filter2(fn,f);
fy = filter2(fn',f);
% 计算矩阵中的元素
% 设定尺度大小为5*5，sigma为2的高斯核
w = fspecial('gaussian',[5 5],2);
A = filter2(w,fx.^2);
B = filter2(w,fy.^2);
C = filter2(w,fx.*fy);
% f函数矩阵的行尺度
height = size(f,1);
% f 函数矩阵的列尺度
width = size(f,2);
%生成和f同样大小的零矩阵
result = zeros(height, width);

%求依次求出图像中每个像素点的评分函数R
l = zeros(height*width,2);
R = zeros(height,width);
Rmax = 0;
for i = 1:height
    for j = 1:width
        M = [A(i,j),C(i,j);C(i,j),B(i,j)];
        R(i,j) = det(M)-k*((trace(M)))^2;   
        if (R(i,j)>Rmax)
            Rmax = R(i,j);
        end
    end
end
% 提取出高于阈值的像素点来作为角点
R_corner = (R>=(q*Rmax)).*R;
%在窗口的左侧绘制通过滤波后角点的位置
[x1,y1] = find(R_corner~=0);

subplot(1,2,1),imshow(I),title('CornerDetector');
hold on 
plot(y1,x1,'b*')
hold off
% 找出每个点[8,8]领域内的最大响应点?非极大值抑制
[xp,yp] = find(imregionalmax(R_corner,8));
%在窗口的右侧，在原图上标记上角点
subplot(1,2,2),imshow(I), title('CornerDetectorAfterNMS'),
hold on
plot(yp,xp, 'b*');
hold off
