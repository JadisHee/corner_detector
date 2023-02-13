

(*触发信号处理*)
fbExecuteEdge(CLK:= (bXmlSrvWrite AND NOT bXmlSrvRead AND NOT bFileDelete) OR
					    (bXmlSrvRead AND NOT bXmlSrvWrite AND NOT bFileDelete) OR
					    (bFileDelete AND NOT bXmlSrvWrite AND NOT bXmlSrvRead) );

IF fbExecuteEdge.Q AND NOT bBusy AND NOT bError THEN
	IF bXmlSrvWrite THEN
		eOperation :=XML_SRV_WRITE;
	ELSIF bXmlSrvRead THEN
		eOperation :=XML_SRV_READ;
	ELSIF bFileDelete THEN
		eOperation := FILE_DELETE;
	END_IF;
	nStep :=1;
END_IF;

(*系统选择*)
IF eWindows = WINCE THEN
	sPathName := '\Hard Disk\UserData' ;
ELSIF eWindows = WINDOWS7 THEN
	sPathName := 'C:\TwinCATUserData';
ELSIF eWindows = WINDOWS10 THEN
	sPathName := 'C:\TwinCATUserData';
END_IF;

IF sFileName ='' THEN
	sTempFileName := 'Data' ;
ELSE
	sTempFileName := sFileName ;
END_IF;

IF RIGHT(sTempFileName, 4)= '.xml' THEN
	sTempFileName :=sTempFileName;
ELSE
	sTempFileName :=CONCAT(sTempFileName, '.xml');
END_IF;




CASE nStep OF
	1:
	(*检查输入路径是否存在*)
	fbEnumFindFileEntry(
		sNetId:= sNetId ,
		sPathName:=sPathName ,
		eCmd:=eEnumCmd_First ,
		bExecute:= TRUE,
		tTimeout:=T#5S );
	IF NOT fbEnumFindFileEntry.bBusy THEN
		fbEnumFindFileEntry(bExecute:= FALSE);
		IF NOT fbEnumFindFileEntry.bError THEN
			IF fbEnumFindFileEntry.bEOE THEN
				nStep :=10 ; (*指定输入路径不存在，跳转至路径生成*)
			ELSE
				nStep :=11 ; (*指定输入路径存在，跳转至数据处理*)
			END_IF;
		ELSE
			bError := TRUE;
			nErrId := fbCreateDirectory.nErrId ;
			nStep := 0 ;
		END_IF;
	END_IF;

	10:
	(*生成路径*)
	fbCreateDirectory(
		sNetId:=sNetId,
		sPathName:= sPathName,
		ePath:=PATH_GENERIC ,
		bExecute:=TRUE ,
		tTimeout:=t#5s );
	IF NOT fbCreateDirectory.bBusy THEN
		fbCreateDirectory(bExecute:= FALSE );
		IF NOT  fbCreateDirectory.bError THEN
			nStep := 1 ;
		ELSE
			bError := TRUE;
			nErrId := fbCreateDirectory.nErrId ;
			nStep := 0 ;
		END_IF;
	END_IF;

	11:
	(*计算数据处理次数*)
	IF cbSymSize > SGL_FILE_BYTE_LEN THEN
		nTotalTimes:=SEL( (cbSymSize MOD SGL_FILE_BYTE_LEN)>0,
						     cbSymSize/SGL_FILE_BYTE_LEN ,
						     cbSymSize/SGL_FILE_BYTE_LEN + 1 );
	ELSE
		nTotalTimes := 1;
	END_IF;
	nSerialNum := 0;(*处理序号清零*)
	nStep := 20;

	20:
	(*数据处理排序*)
	sFilePath :=CONCAT(CONCAT(sPathName,'\'),sTempFileName);
	IF nTotalTimes > nSerialNum THEN
		nSerialNum := nSerialNum + 1;
		nStep := 21;
	ELSE
		nStep := 0;
	END_IF;

	21:
	pTmpSymAddr := pSymAddr + (nSerialNum-1)*SGL_FILE_BYTE_LEN;
	(*计算所需当前处理次数所需处理数据长度：最大值1000*)
	IF cbSymSize<SGL_FILE_BYTE_LEN THEN
		nTmpDataSize := cbSymSize;
	ELSE
		IF nSerialNum < nTotalTimes THEN
			nTmpDataSize := SGL_FILE_BYTE_LEN;
		ELSE
			nTmpDataSize := cbSymSize-SGL_FILE_BYTE_LEN*(nSerialNum-1);
		END_IF;
	END_IF;
	sFilePath := INSERT (sFilePath,UDINT_TO_STRING(nSerialNum),LEN(sFilePath)-4 );
	nStep := 22;

	22:
	(*功能选择*)
	IF eOperation = XML_SRV_WRITE THEN
		nStep := 30 ;
	ELSIF eOperation = XML_SRV_READ THEN
		nStep := 40;
	ELSIF eOperation = FILE_DELETE THEN
		nStep := 50 ;
	ELSE
		nStep := 0 ;
	END_IF;

	30:(*数据存储：获取所需存储部分数据*)
	MEMCPY(ADR(arrTmpData) , pTmpSymAddr , nTmpDataSize);
	nStep := 31;

	31:(*数据存储：存储数据*)
	fbXmlSrvWrite(
		sNetId:= sNetId,
		ePath:= PATH_GENERIC,
		nMode:= XMLSRV_ADDMISSING,
		pSymAddr:= ADR(arrTmpData),
		cbSymSize:= SIZEOF(arrTmpData),
		sFilePath:= sFilePath,
		sXPath:= sXPath,
		bExecute:= TRUE,
		tTimeout:= T#5S );
	IF NOT fbXmlSrvWrite.bBusy THEN
		fbXmlSrvWrite(bExecute:=FALSE);
		IF NOT fbXmlSrvWrite.bError THEN
			IF nTotalTimes = nSerialNum THEN(*数据读取完成后置位DONE信号*)
				bDone := TRUE;
			END_IF;
			nStep := 20 ;
		ELSE
			bError := TRUE;
			nErrId := fbXmlSrvWrite.nErrId ;
			nStep := 20 ;
		END_IF;
	END_IF;

	40:(*读取数据:清空数据暂存区域*)
	MEMSET(ADR(arrTmpData) , 0 , SIZEOF(arrTmpData));
	nStep := 41;

	41:(*读取数据*)
	fbXmlSrvRead(
		sNetId:=sNetId ,
		ePath:=PATH_GENERIC ,
		nMode:=XMLSRV_SKIPMISSING ,
		pSymAddr:=ADR(arrTmpData),
		cbSymSize:=SIZEOF(arrTmpData),
		sFilePath:= sFilePath,
		sXPath:= sXPath,
		bExecute:=TRUE,
		tTimeout:=T#5S  );
	IF NOT fbXmlSrvRead.bBusy THEN
		fbXmlSrvRead(bExecute:=FALSE);
		IF NOT fbXmlSrvRead.bError THEN
			IF nTotalTimes = nSerialNum THEN(*数据处理完成后置位DONE信号*)
				bDone := TRUE;
			END_IF;
			MEMCPY(pTmpSymAddr , ADR(arrTmpData) , nTmpDataSize);
			nStep := 20 ;
		ELSE
			bError := TRUE;
			nErrId := fbXmlSrvRead.nErrId ;
			nStep := 20 ;
		END_IF;
	END_IF;

	50:
	(*文件删除*)
	fbFileDelete(
		sNetId:=sNetId,
		sPathName:=sFilePath ,
		ePath:=PATH_GENERIC ,
		bExecute:=TRUE ,
		tTimeout:= t#5s );
	IF NOT fbFileDelete.bBusy THEN
		fbFileDelete(bExecute:=FALSE);
		IF NOT fbFileDelete.bError THEN
			IF nTotalTimes = nSerialNum THEN(*数据处理完成后置位DONE信号*)
				bDone := TRUE;
			END_IF;
			nStep := 20 ;
		ELSE
			bError := TRUE;
			nErrId := fbFileDelete.nErrId ;
			nStep := 20 ;
		END_IF;
	END_IF;

END_CASE;

IF nStep<>0 THEN
	bBusy:=TRUE;
ELSE
	bBusy := FALSE;
END_IF;

(*无触发信号，程序自动复位*)
IF  NOT bXmlSrvWrite AND NOT  bXmlSrvRead AND NOT bFileDelete THEN
	(*无正在执行功能块，复位循环*)
	IF NOT fbEnumFindFileEntry.bBusy AND NOT fbCreateDirectory.bBusy AND NOT
	fbFileDelete.bBusy AND NOT fbXmlSrvWrite.bBusy AND NOT
	fbXmlSrvWrite.bBusy AND NOT fbXmlSrvRead.bBusy THEN
		nStep := 0;
	END_IF;
	nErrId := 0 ;
	bDone := FALSE;
	bError := FALSE;
END_IF;
