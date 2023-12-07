a1=7200;
a2=6;
a3=48;
a4=7;
a5=3;
b1=9600;
b2=12;
b3=24;
b4=10;
b5=5;
c1=4800;
c2=12;
c3=72;
c4=10;
c5=8;
cluster1=[6000,5,40,6,3];
cluster2=[8000,10,20,8,5];
cluster3=[4000,10,60,8,8];
user=[2000,1,10,1];
manzushu=0;
junhenglv=[0,0,0,0,0,0,0,0,0];
tag=2;
if tag==0
    for i=1:9
        flag=0;             
        for j=1:4
            if cluster1(j)>0
                cluster1(j)=cluster1(j)-user(j);
                if cluster1(j)<0
                    cluster1(j)=0;
                    flag=1;
                end
            else
                flag=1;
            end
        end
        junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
        if flag==0
            manzushu=manzushu+1;
        end
    end
end
if tag==1
    for i=1:9
        flag=0;
        C11cha=cluster1(1)-user(1);
        C12cha=cluster1(2)-user(2);
        C13cha=cluster1(3)-user(3);
        C14cha=cluster1(4)-user(4);
        if C11cha<0||C12cha<0||C13cha<0||C14cha<0
            leastscore1=0;
            balancescore1=0;
            netscore1=1-cluster1(5)/10;
            clusterscore1=leastscore1+balancescore1+netscore1;
        else
            flag=1;
            leastscore1=(C11cha/a1+C12cha/a2+C13cha/a3+C14cha/a4)/4;
            balancescore1=1-(abs((a1-C11cha)/a1-(a2-C12cha)/a2)+abs((a1-C11cha)/a1-(a3-C13cha)/a3)+abs((a1-C11cha)/a1-(a4-C14cha)/a4)+ ...
                          abs((a2-C12cha)/a2-(a3-C13cha)/a3)+abs((a2-C12cha)/a2-(a4-C14cha)/a4)+abs((a3-C13cha)/a3-(a4-C14cha)/a4))/6;
            netscore1=1-cluster1(5)/10;
            clusterscore1=leastscore1+balancescore1+netscore1;
        end
        C21cha=cluster2(1)-user(1);
        C22cha=cluster2(2)-user(2);
        C23cha=cluster2(3)-user(3);
        C24cha=cluster2(4)-user(4);
        if C21cha<0||C22cha<0||C23cha<0||C24cha<0
            leastscore2=0;
            balancescore2=0;
            netscore2=1-cluster2(5)/10;
            clusterscore2=leastscore2+balancescore2+netscore2;
        else
            flag=1;
            leastscore2=(C21cha/b1+C22cha/b2+C23cha/b3+C24cha/b4)/4;
            balancescore2=1-(abs((b1-C21cha)/b1-(b2-C22cha)/b2)+abs((b1-C21cha)/b1-(b3-C23cha)/b3)+abs((b1-C21cha)/b1-(b4-C24cha)/b4)+ ...
                          abs((b2-C22cha)/b2-(b3-C23cha)/b3)+abs((b2-C22cha)/b2-(b4-C24cha)/b4)+abs((b3-C23cha)/b3-(b4-C24cha)/b4))/6;
            netscore2=1-cluster2(5)/10;
            clusterscore2=leastscore2+balancescore2+netscore2;
        end
        C31cha=cluster3(1)-user(1);
        C32cha=cluster3(2)-user(2);
        C33cha=cluster3(3)-user(3);
        C34cha=cluster3(4)-user(4);
        if C31cha<0||C32cha<0||C33cha<0||C34cha<0
            leastscore3=0;
            balancescore3=0;
            netscore3=1-cluster3(5)/10;
            clusterscore3=leastscore3+balancescore3+netscore3;
        else
            flag=1;
            leastscore3=(C31cha/c1+C32cha/c2+C33cha/c3+C34cha/c4)/4;
            balancescore3=1-(abs((c1-C31cha)/c1-(c2-C32cha)/c2)+abs((c1-C31cha)/c1-(c3-C33cha)/c3)+abs((c1-C31cha)/c1-(c4-C34cha)/c4)+ ...
                          abs((c2-C32cha)/c2-(c3-C33cha)/c3)+abs((c2-C32cha)/c2-(c4-C34cha)/c4)+abs((c3-C33cha)/c3-(c4-C34cha)/c4))/6;
            netscore3=1-cluster3(5)/10;
            clusterscore3=leastscore3+balancescore3+netscore3;
        end
        maxscore=max(clusterscore1,max(clusterscore2,clusterscore3));
        if maxscore==clusterscore1
            for j=1:4
                if cluster1(j)>0
                    cluster1(j)=cluster1(j)-user(j);
                    if cluster1(j)<0
                        cluster1(j)=0;
                    end
                end
            end
        elseif maxscore==clusterscore2
            for j=1:4
                if cluster2(j)>0
                    cluster2(j)=cluster2(j)-user(j);
                    if cluster2(j)<0
                        cluster2(j)=0;
                    end
                end
            end
        else
            for j=1:4
                if cluster3(j)>0
                    cluster3(j)=cluster3(j)-user(j);
                    if cluster3(j)<0
                        cluster3(j)=0;
                    end
                end
            end
        end
        junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
        if flag==1
            manzushu=manzushu+1;
        end
    end
end

if tag==2
   for i=1:9
       flag=0;
       for j=1:4
           if cluster1(j)>0
                if cluster1(j)-user(j)<0
                    flag=1;
                end
           else
                flag=1;
           end    
       end
       if flag==0
           cluster1(1)=cluster1(1)-user(1);
           cluster1(2)=cluster1(2)-user(2);
           cluster1(3)=cluster1(3)-user(3);
           cluster1(4)=cluster1(4)-user(4);
           manzushu=manzushu+1;
           junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
       end
       if flag==1
           flag=2;
           for j=1:4
                if cluster2(j)>0
                    if cluster2(j)-user(j)<0
                        flag=3;
                    end
                else
                    flag=3;
                end    
            end
       end
       if flag==2
           cluster2(1)=cluster2(1)-user(1);
           cluster2(2)=cluster2(2)-user(2);
           cluster2(3)=cluster2(3)-user(3);
           cluster2(4)=cluster2(4)-user(4);
           manzushu=manzushu+1;
           junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
       end
       if flag==3
           flag=4;
           for j=1:4
                if cluster3(j)>0
                    if cluster3(j)-user(j)<0
                        flag=5;
                    end
                else
                    flag=5;
                end    
            end
       end
       if flag==4
           cluster3(1)=cluster3(1)-user(1);
           cluster3(2)=cluster3(2)-user(2);
           cluster3(3)=cluster3(3)-user(3);
           cluster3(4)=cluster3(4)-user(4);
           manzushu=manzushu+1;
           junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
       end
       if flag==5
           for j=1:4
                if cluster1(j)>0
                    cluster1(j)=cluster1(j)-user(j);
                    if cluster1(j)<0
                        cluster1(j)=0;
                    end
                end
           end
           junhenglv(i)=1-(abs((a1-cluster1(1))/a1-(b1-cluster2(1))/b1)+abs((a1-cluster1(1))/a1-(c1-cluster3(1))/c1)+abs((b1-cluster2(1))/b1-(c1-cluster3(1))/c1)+ ...
                     abs((a2-cluster1(2))/a2-(b2-cluster2(2))/b2)+abs((a2-cluster1(2))/a2-(c2-cluster2(2))/c2)+abs((b2-cluster2(2))/b2-(c2-cluster3(2))/c2)+ ...
                     abs((a3-cluster1(3))/a3-(b3-cluster2(3))/b3)+abs((a3-cluster1(3))/a3-(c3-cluster3(3))/c3)+abs((b3-cluster2(3))/b3-(c3-cluster3(3))/c3)+ ...
                     abs((a4-cluster1(4))/a4-(b4-cluster2(4))/b4)+abs((a4-cluster1(4))/a4-(c4-cluster3(4))/c4)+abs((b4-cluster2(4))/b4-(c4-cluster3(4))/c4))/12;
       end
   end
end

disp(manzushu);
disp(junhenglv);
