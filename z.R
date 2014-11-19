#读取报告国的总表,计算import/export平均值
aveline<-function(x){
	m<-as.matrix(read.table(r, header=T))
	mlen<-ncol(m)
	im<-0
	ex<-0
	for(i in seq(2,mlen,by=3))
	{
		im<-m[,i]+im
		ex<-m[,i+1]+ex
	}
	per<-(100*im)%/%ex
}

#将曲率表生成图像
getPicture<-function(x)
{
	png(paste(r,".png", sep=""),width=1200, height=700)
	plot(t[[1]],t[[2]], type="n",xlab="Type",ylab="Per",ylim=c(0,200),main=(paste(r, "Import/export ")))
	len<-length(t)
	for (i in 2:len){
		lines(t[,1],t[,i],col=i,lty=i,lwd=3)
	}
	lines(t[,1],t[,len],col=i,lwd=6,lty=1)
	legend("topleft",dimnames(t)[[2]],col=1:len,lty=1:len,box.col="white")
	dev.off()
}

args<-commandArgs(T)
r<-args[1]
m<-args[2]
if(m == 2)
{
	t<-read.table(paste(r,"_p",sep="" ),header=TRUE)
	t$ave<-aveline(r)
	write.table(t,paste(r,"_p",sep=""),row.names=F)
}else
{
	t<-read.table(r,header=TRUE)
	getPicture(t)
}
#browser()
