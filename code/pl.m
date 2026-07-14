
x = xlsread('test1_200.csv', 'test1_200', 'B2:B1746');
[alpha_noncontam, xmin_1, L_1] = plfit(x,'finite');
h1 = plplot(x,xmin_1,alpha_noncontam);

% h = get(gca, 'children')
% x = get(h(1), 'xdata')
% y = get(h(1), 'ydata')
