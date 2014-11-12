args<-commandArgs(T)
pdf(paste(args[1],".pdf", sep=""))
t<-read.table(paste(args[1],".p",sep=""),header=TRUE)
plot(t$X0,t$X842, type="n",xlab="Type",ylab="Per",ylim=c(0,200),main="China Import In 2013")
for (i in 2:10){
	lines(t[,1],t[,i],col=i,lty=i-1)
}
legend("topleft",dimnames(t)[[2]],col=2:10,lty=1:9,box.col="white")
dev.off()
