USE [JenniferDev]
GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Action]    Script Date: 11-04-2021 20:41:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Catalogue_Action]
@json varchar(max)
as
begin
begin try
	begin transaction
	
		set @json = CONCAT('[', @json, ']') 
		
		declare @ImagePath varchar(300)
		declare @ActionMessage varchar(100)
		declare @Action varchar(10)
		declare @CustomName varchar(100) 
		declare @SellerFormID int
		declare @CatalogueNumber varchar(30) 
		declare @Seller_CatalogueStatus  varchar(30)  
		declare @Remarks  varchar(500)  
		declare @LoginId  UserID  
		-- MAIL SENDING
		declare @SellerEmail varchar(50)	
		declare @RKSellerID varchar(30)	 
		declare @IOREmail varchar(50)
		declare @EOREmail varchar(50)
		declare @Email_CC varchar(5000)
		declare @MarketPlaceSellerID varchar(30)		
		declare @Msg nvarchar(1000)
		declare @LanguageType varchar(10)
		declare @lstCatalogueDocPathDetail varchar(max)
		declare @lstCatalogueImagePathDetail varchar(max)
		declare @CatalogueID bigint

		set @Action = JSON_VALUE(@json, '$[0].Action')
		set @LoginId = JSON_VALUE(@json, '$[0].LoginId') 
		set @SellerFormID = JSON_VALUE(@json, '$[0].SellerFormID') 
		set @Seller_CatalogueStatus = JSON_VALUE(@json, '$[0].SellerStatus')		 
		set @Remarks = JSON_VALUE(@json, '$[0].Remarks')  

		set @lstCatalogueDocPathDetail = JSON_QUERY(@json, '$[0].lstCatalogueDocPathDetail')	 
		set @lstCatalogueImagePathDetail = JSON_QUERY(@json, '$[0].lstCatalogueImagePathDetail')	
	
		set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType') 
		
		declare @CountryID tinyint 
		declare @ProductName varchar(100)  
		declare @MerchantSKU varchar(100)  
		declare @ASIN varchar(100)  
		declare @ProductDescription varchar(500)  
		declare @HSNCode varchar(100)  
		if(@Action = 'I')
		begin	 
			set @ActionMessage = 'added'
			SET @CatalogueNumber =( SELECT TOP 1 CatalogueNumber FROM Catalogue.CatalogueUniqueMaster U
			WHERE NOT EXISTS  	(SELECT 1 FROM Catalogue.CatalogueHeader AS M WHERE M.CatalogueNumber=U.CatalogueNumber )) 

			Insert into [Catalogue].[CatalogueHeader] (SellerFormID,CatalogueNumber,CatalogueDate,
			Seller_CatalogueStatus,Custom_CatalogueStatus,IOR_CatalogueStatus,EOR_CatalogueStatus,
			LastModifiedBy,LastModifiedDate)
			values (@SellerFormID, @CatalogueNumber, getdate(), 
			'Under Review','New','Under Review','Under Review',
			@LoginId, getdate())

			set @CatalogueID = SCOPE_IDENTITY()

			-- history data
			Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
			LastModifiedBy,LastModifiedDate)
			values (@CatalogueID, 'New', 'Newly Added',
			@LoginId, getdate())  

			-- detail data insert 
			set @CountryID = JSON_VALUE(@json, '$[0].CountryID') 
			set @ProductName = JSON_VALUE(@json, '$[0].ProductName') 
			set @MerchantSKU = JSON_VALUE(@json, '$[0].MerchantSKU') 
			set @ASIN = JSON_VALUE(@json, '$[0].ASIN') 
			set @ProductDescription = JSON_VALUE(@json, '$[0].ProductDescription') 
			set @HSNCode = JSON_VALUE(@json, '$[0].HSNCode')  

			Declare @CatalogueDetailID INT 
			Insert into [Catalogue].[CatalogueDetail] (CatalogueID,CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
			HSNCode,LastModifiedBy,LastModifiedDate)
			select @CatalogueID,@CountryID,@ProductName,@MerchantSKU,@ASIN,@ProductDescription,
			@HSNCode,@LoginId, getdate() 
			
			SET @CatalogueDetailID=@@IDENTITY
			 
			select top 1 @ImagePath=ImagePath    from
			openjson(@lstCatalogueImagePathDetail) 
			with (
				ImagePath varchar(300) '$.ImagePath'
			)  
			update [Catalogue].[CatalogueDetail] set ImagePath=@ImagePath
			where CatalogueDetailID=@CatalogueDetailID

			
			insert into [Catalogue].CatalogueImageDetail(CatalogueDetailID,ImagePath,LastModifiedBy,LastModifiedDate)
			select @CatalogueDetailID CatalogueDetailID, ImagePath,@LoginId as LastmodifiedBy,
			GETDATE() as lastModifiedDate    from
			openjson(@lstCatalogueImagePathDetail) 
			with (
				ImagePath varchar(300) '$.ImagePath'
			)

			insert into [Catalogue].CatalogueDocumentDetail
			(CatalogueDetailID,DocumentPath,LastModifiedBy,LastModifiedDate) 
			select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId as LastmodifiedBy,
			GETDATE() as lastModifiedDate   from
			openjson(@lstCatalogueDocPathDetail) 
			with (
				DocPath varchar(300) '$.DocPath'
			) 

			-- updating draf files status
			update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from
			openjson(@lstCatalogueImagePathDetail ) 
			with (
				ImagePath varchar(300) '$.ImagePath'
			)) 
			
			update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from  
			openjson(@lstCatalogueDocPathDetail) 
			with (
				DocPath varchar(300) '$.DocPath'
			))
		


			---- mail sending to sellers as to
			---- others in cc 
			--select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
			--@IOREmail=c.email, 
			--@EOREmail=v.email from Catalogue.SellerRegistration as sr  
			--inner join register.company c on c.companyid=sr.IORPartnerID 
			--inner join masters.vendor v on v.vendorid=sr.vendorid  
			--where sr.SellerFormID =@SellerFormID

			----custome admins get based on user type 9
			--SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
			--FROM Register.Users where usertype in ('9')
			--set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

			--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_New @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 
			--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Custom_Update @IOREmail,@RKSellerID,@CustomName,
			--@CatalogueNumber,@Email_CC 	

			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Added'
				
			select @Msg as Msg ,cast(1 as bit) as Flag
			--select 'Catalogue has been added successfully' as Msg ,cast(1 as bit) as Flag 
		end
		else if (@Action='U')
		begin
		
			
			set @CatalogueDetailID = JSON_VALUE(@json, '$[0].CatalogueDetailID') 

			if exists(select 1 from [Catalogue].CatalogueHeader as a 
			inner join [Catalogue].Cataloguedetail cd on cd.Catalogueid=a.Catalogueid
			where Cataloguedetailid = @Cataloguedetailid
			and isnull(Seller_CatalogueStatusUpdateCount,0) =0 and (Seller_CatalogueStatus='Requested To Resend' ))
			Begin
				set @ActionMessage = 'updated' 
				 
				select @CatalogueID=CatalogueID from [Catalogue].Cataloguedetail where Cataloguedetailid=@CatalogueDetailID

				update [Catalogue].CatalogueHeader set  
				Seller_CatalogueStatus = 'Under Review' ,
				Custom_CatalogueStatus = 'Resent By Merchant' ,
				IOR_CatalogueStatus = 'Resent By Merchant' ,
				EOR_CatalogueStatus = 'Under Review' ,
				Seller_CatalogueStatusUpdateCount=1
				where CatalogueID =@CatalogueID
						
				Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
				LastModifiedBy,LastModifiedDate)
				values (@CatalogueID, 'Resent', @Remarks,
				@LoginId, getdate())

				
				set @CountryID = JSON_VALUE(@json, '$[0].CountryID') 
				set @ProductName = JSON_VALUE(@json, '$[0].ProductName') 
				set @MerchantSKU = JSON_VALUE(@json, '$[0].MerchantSKU') 
				set @ASIN = JSON_VALUE(@json, '$[0].ASIN') 
				set @ProductDescription = JSON_VALUE(@json, '$[0].ProductDescription') 
				set @HSNCode = JSON_VALUE(@json, '$[0].HSNCode')  

				delete c from Catalogue.CatalogueHeader a inner join [Catalogue].[CatalogueDetail] b
				on a.CatalogueID=b.CatalogueID inner join Catalogue.CatalogueDocumentDetail c on c.CatalogueDetailID=b.CatalogueDetailID
				where b.CatalogueDetailID=@CatalogueDetailID

				delete c from Catalogue.CatalogueHeader a inner join [Catalogue].[CatalogueDetail] b
				on a.CatalogueID=b.CatalogueID inner join Catalogue.CatalogueImageDetail c
				on c.CatalogueDetailID=b.CatalogueDetailID
				where b.CatalogueDetailID=@CatalogueDetailID
			
				update [Catalogue].[CatalogueDetail]
				set CountryID=@CountryID,
				ProductName=@ProductName,	
				MerchantSKU=@MerchantSKU,	
				ASIN=@ASIN,	
				ProductDescription=@ProductDescription,	
				HSNCode=@HSNCode
				where CatalogueDetailID=@CatalogueDetailID 

				select top 1 @ImagePath=ImagePath    from
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)  
				update [Catalogue].[CatalogueDetail] set ImagePath=@ImagePath
				where CatalogueDetailID=@CatalogueDetailID

				-- image and document detail insert
				
				insert into [Catalogue].CatalogueImageDetail(CatalogueDetailID,ImagePath,LastModifiedBy,LastModifiedDate)
				select @CatalogueDetailID CatalogueDetailID, ImagePath,@LoginId as LastmodifiedBy,
				GETDATE() as lastModifiedDate    from
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)

				insert into [Catalogue].CatalogueDocumentDetail
				(CatalogueDetailID,DocumentPath,LastModifiedBy,LastModifiedDate) 
				select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId as LastmodifiedBy,
				GETDATE() as lastModifiedDate   from
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				)  
				-- updating draf files status
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from
				openjson(@lstCatalogueImagePathDetail ) 
				with (
				ImagePath varchar(300) '$.ImagePath'
				)) 
			
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from  
				openjson(@lstCatalogueDocPathDetail) 
				with (
				DocPath varchar(300) '$.DocPath'
				))
		
				---- mail sending to sellers as to
				---- others in cc  
				--select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
				--@IOREmail=c.email, 
				--@EOREmail=v.email from Catalogue.SellerRegistration as sr  
				--inner join register.company c on c.companyid=sr.IORPartnerID 
				--inner join masters.vendor v on v.vendorid=sr.vendorid  
				--where sr.SellerFormID =@SellerFormID

				----custome admins get based on user type 9
				--SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
				--FROM Register.Users where usertype in ('9')
				--set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

				--SELECT TOP 1 @CatalogueNumber= CatalogueNumber FROM Catalogue.CatalogueHeader  WHERE  CatalogueID=@CatalogueID  

				--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_ReSend @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 
				
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Updated'
				
				select @Msg as Msg ,cast(1 as bit) as Flag 
				--select 'Catalogue has been updated successfully' as Msg ,cast(1 as bit) as Flag 
			end
			else
			begin  
		
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Error_AlreadyUpdated'
				
				select @Msg as Msg ,cast(0 as bit) as Flag
				--select 'The Catalogue already updated one time. So you can''t update again and again.!' as Msg ,cast(0 as bit) as Flag
			end
		end
		else if (@Action='W')
		begin

			if exists(select 1 from [Catalogue].CatalogueHeader where CatalogueID = @CatalogueID
			and (IOR_CatalogueStatus='Resend To Merchant' or Custom_CatalogueStatus='New'))
			Begin 


				set @CatalogueDetailID = JSON_VALUE(@json, '$[0].CatalogueDetailID')  

				select @CatalogueID=CatalogueID from [Catalogue].Cataloguedetail where Cataloguedetailid=@CatalogueDetailID

				set @LoginId = JSON_VALUE(@json, '$[0].LoginId') 
				set @Remarks = JSON_VALUE(@json, '$[0].Remarks') 
		 

				update [Catalogue].CatalogueHeader set Seller_CatalogueStatus = 'Withdrawn' ,
				Custom_CatalogueStatus = 'Withdrawn' ,
				IOR_CatalogueStatus = 'Withdrawn' ,
				EOR_CatalogueStatus = 'Withdrawn' 
				where CatalogueID = @CatalogueID
						
				Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
				LastModifiedBy,LastModifiedDate)
				values (@CatalogueID, 'Withdrawn', @Remarks,
				@LoginId, getdate())


				---- mail sending to sellers as to
				---- others in cc  
				--select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
				--@IOREmail=c.email, 
				--@EOREmail=case when v.vendorid=5 then '' else  v.email end
				----v.email 
				--from Catalogue.SellerRegistration as sr  
				--inner join register.company c on c.companyid=sr.IORPartnerID 
				--inner join masters.vendor v on v.vendorid=sr.vendorid  
				--where sr.SellerFormID =@SellerFormID

				----custome admins get based on user type 9
				--SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
				--FROM Register.Users where usertype in ('9')
				--set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

				--SELECT TOP 1 @CatalogueNumber= CatalogueNumber FROM Catalogue.CatalogueHeader  WHERE  CatalogueID=@CatalogueID  

				--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_Withdrawn @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 

				--select @Msg = LanguageError from [Register].[Language_Key] 
				--where LanguageType = @LanguageType and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Withdrawn'
				
				--select @Msg as Msg ,cast(1 as bit) as Flag 

				----select 'Catalogue has been withdrawn successfully' as Msg ,cast(1 as bit) as Flag 
		
			end
			else
			begin
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Error_CantWithdraw'
				
				select @Msg as Msg ,cast(0 as bit) as Flag 
				--select 'The Catalogue has been updated By Consultant/IOR. So you can''t withdraw now.!' as Msg ,cast(0 as bit) as Flag
				 
			end
		end
	commit

end try
begin catch
	if @@TRANCOUNT > 0
	Begin
		rollback;
		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select  @SellerFormID,'Catalogue -'+@Action,@CatalogueNumber,ERROR_MESSAGE(),GETDATE()
		
		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Failed'
				
		select @Msg as Msg ,cast(0 as bit) as Flag 
	End
end catch

end


GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Action_old]    Script Date: 11-04-2021 20:41:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create procedure [Seller].[usp_Catalogue_Action_old]
@json varchar(max)
as
begin
begin try
	begin transaction
	
		set @json = CONCAT('[', @json, ']')

		if object_id('tempdb..#CatalogueDocumentDetail1', 'U') is not null
		BEGIN
			drop table  #CatalogueDocumentDetail1 
		END 
		if object_id('tempdb..#CatalogueImageDetail1', 'U') is not null
		BEGIN
			drop table  #CatalogueImageDetail1 
		END 

		declare @ActionMessage varchar(100)
		declare @Action varchar(10)
		declare @CustomName varchar(100)
		declare @CatalogueID bigint
		declare @SellerFormID int
		declare @CatalogueNumber varchar(30) 
		declare @Seller_CatalogueStatus  varchar(30)  
		declare @Remarks  varchar(500)  
		declare @LoginId  UserID 
		declare @lstCatalogueDetail varchar(max)
		-- MAIL SENDING
		declare @SellerEmail varchar(50)	
		declare @RKSellerID varchar(30)	 
		declare @IOREmail varchar(50)
		declare @EOREmail varchar(50)
		declare @Email_CC varchar(5000)
		declare @MarketPlaceSellerID varchar(30)		
		declare @Msg nvarchar(1000)
		declare @LanguageType varchar(10)
		declare @lstCatalogueDocPathDetail varchar(max)
		declare @lstCatalogueImagePathDetail varchar(max)

		set @Action = JSON_VALUE(@json, '$[0].Action')
		set @LoginId = JSON_VALUE(@json, '$[0].LoginId')
		set @CatalogueID = JSON_VALUE(@json, '$[0].CatalogueID')
		set @SellerFormID = JSON_VALUE(@json, '$[0].SellerFormID') 
		set @Seller_CatalogueStatus = JSON_VALUE(@json, '$[0].Seller_CatalogueStatus')		 
		set @Remarks = JSON_VALUE(@json, '$[0].Remarks') 
		set @lstCatalogueDetail = JSON_QUERY(@json, '$[0].lstCatalogueDetail')

		set @lstCatalogueDocPathDetail = JSON_QUERY(@json, '$[0].lstCatalogueDocPathDetail')	 
		set @lstCatalogueImagePathDetail = JSON_QUERY(@json, '$[0].lstCatalogueImagePathDetail')	
	
		set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType') 

		if(@Action = 'I')
		begin	 
			set @ActionMessage = 'added'
			SET @CatalogueNumber =( SELECT TOP 1 CatalogueNumber FROM Catalogue.CatalogueUniqueMaster U WHERE NOT EXISTS 
			(SELECT 1 FROM Catalogue.CatalogueHeader AS M WHERE M.CatalogueNumber=U.CatalogueNumber )) 
			Insert into [Catalogue].[CatalogueHeader] (SellerFormID,CatalogueNumber,CatalogueDate,
			Seller_CatalogueStatus,Custom_CatalogueStatus,IOR_CatalogueStatus,EOR_CatalogueStatus,
			LastModifiedBy,LastModifiedDate)
			values (@SellerFormID, @CatalogueNumber, getdate(), 
			'Under Review','New','Under Review','Under Review',
			@LoginId, getdate())

			set @CatalogueID = SCOPE_IDENTITY()

			Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
			LastModifiedBy,LastModifiedDate)
			values (@CatalogueID, 'New', 'Newly Added',
			@LoginId, getdate()) 

			
			if object_id('tempdb..#t1', 'U') is not null
			BEGIN
				drop table  #t1 
			END 


			select CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
			HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
			DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,Certificates,Custom_Remarks,Custom_Status,
			IOR_Status,EOR_Status into #t1  from
			openjson(@lstCatalogueDetail) 
			with (
				CountryID tinyint '$.CountryID',
				ProductName varchar(100) '$.ProductName',
				MerchantSKU varchar(100) '$.MerchantSKU',
				ASIN varchar(100) '$.ASIN',
				ProductDescription varchar(500) '$.ProductDescription',
				HSNCode varchar(100) '$.HSNCode',
				DeclareValueInDollar decimal(18,2) '$.DeclareValueInDollar',
				MRPInINR decimal(18,2) '$.MRPInINR',
				SellingPriceInINR decimal(18,2) '$.SellingPriceInINR',
				ImagePath varchar(300) '$.ImagePath',
				DocumentPath1 varchar(300) '$.DocumentPath1',				
				DocumentPath2 varchar(300) '$.DocumentPath2',
				DocumentPath3 varchar(300) '$.DocumentPath3',
				CTH_HSN varchar(100) '$.CTH_HSN',
				BCD decimal(18,2) '$.BCD',
				SWS decimal(18,2) '$.SWS',
				IGST decimal(18,2) '$.IGST',
				Others varchar(500) '$.Others',
				Certificates varchar(500) '$.Certificates',
				Custom_Remarks varchar(500) '$.Custom_Remarks',
				Custom_Status varchar(30) '$.Custom_Status',
				IOR_Status varchar(30) '$.IOR_Status',				
				EOR_Status varchar(30) '$.EOR_Status'
			)

			Declare @CatalogueDetailID INT 
			Insert into [Catalogue].[CatalogueDetail] (CatalogueID,CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
			HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
			DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,Certificates,Custom_Remarks,Custom_Status,
			IOR_Status,EOR_Status,LastModifiedBy,LastModifiedDate)
			select @CatalogueID,CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
			HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
			DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,Certificates,Custom_Remarks,Custom_Status,
			IOR_Status,EOR_Status, @LoginId, getdate() from #t1  
			
			SET @CatalogueDetailID=@@IDENTITY

			select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId as LastmodifiedBy,GETDATE() as lastModifiedDate 
			into #CatalogueDocumentDetail  from
			openjson(@lstCatalogueDocPathDetail) 
			with (
				DocPath varchar(300) '$.DocPath'
			)
			insert into [Catalogue].CatalogueDocumentDetail
			select * from #CatalogueDocumentDetail

			select @CatalogueDetailID CatalogueDetailID, ImagePath,@LoginId as LastmodifiedBy,GETDATE () as lastModifiedDate 
			into #CatalogueImageDetail  from
			openjson(@lstCatalogueImagePathDetail) 
			with (
				ImagePath varchar(300) '$.ImagePath'
			)
			insert into [Catalogue].CatalogueImageDetail
			select * from #CatalogueImageDetail

			update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from #CatalogueDocumentDetail)
			update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from #CatalogueImageDetail)
		


			-- mail sending to sellers as to
			-- others in cc 
			select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
			@IOREmail=c.email, 
			@EOREmail=v.email from Catalogue.SellerRegistration as sr  
			inner join register.company c on c.companyid=sr.IORPartnerID 
			inner join masters.vendor v on v.vendorid=sr.vendorid  
			where sr.SellerFormID =@SellerFormID

			--custome admins get based on user type 9
			SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
			FROM Register.Users where usertype in ('9')
			set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

			exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_New @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 
			exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Custom_Update @IOREmail,@RKSellerID,@CustomName,
					@CatalogueNumber,@Email_CC 	
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Added'
				
			select @Msg as Msg ,cast(1 as bit) as Flag
			--select 'Catalogue has been added successfully' as Msg ,cast(1 as bit) as Flag 
		end
		else if (@Action='U')
		begin
		
			if exists(select 1 from [Catalogue].CatalogueHeader where CatalogueID = @CatalogueID
			and isnull(Seller_CatalogueStatusUpdateCount,0) =0 and (IOR_CatalogueStatus='Resend To Merchant' ))
			Begin
				set @ActionMessage = 'updated' 

				update [Catalogue].CatalogueHeader set  
				Seller_CatalogueStatus = 'Under Review' ,
				Custom_CatalogueStatus = 'Resent By Merchant' ,
				IOR_CatalogueStatus = 'Resent By Merchant' ,
				EOR_CatalogueStatus = 'Under Review' ,
				Seller_CatalogueStatusUpdateCount=1
				where CatalogueID = @CatalogueID
						
				Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
				LastModifiedBy,LastModifiedDate)
				values (@CatalogueID, 'Resent', @Remarks,
				@LoginId, getdate())

				if object_id('tempdb..#t2', 'U') is not null
				BEGIN
					drop table  #t2 
				END 

				SELECT distinct CatalogueDetailID,CatalogueID,
				CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
				HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
				DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,Custom_Remarks,Custom_Status,
				IOR_Status,EOR_Status 
				 into #t2 FROM
				OPENJSON ( @lstCatalogueDetail )  
				WITH (      
					CatalogueDetailID bigint  '$.CatalogueDetailID' ,
					CatalogueID bigint  '$.CatalogueID' ,
					CountryID tinyint '$.CountryID',
					ProductName varchar(100) '$.ProductName',
					MerchantSKU varchar(100) '$.MerchantSKU',
					ASIN varchar(100) '$.ASIN',
					ProductDescription varchar(500) '$.ProductDescription',
					HSNCode varchar(100) '$.HSNCode',
					DeclareValueInDollar decimal(18,2) '$.DeclareValueInDollar',
					MRPInINR decimal(18,2) '$.MRPInINR',
					SellingPriceInINR decimal(18,2) '$.SellingPriceInINR',
					ImagePath varchar(300) '$.ImagePath',
					DocumentPath1 varchar(300) '$.DocumentPath1',
					DocumentPath2 varchar(300) '$.DocumentPath2',
					DocumentPath3 varchar(300) '$.DocumentPath3',
					CTH_HSN varchar(100) '$.CTH_HSN',
					BCD decimal(18,2) '$.BCD',
					SWS decimal(18,2) '$.SWS',
					IGST decimal(18,2) '$.IGST',
					Others varchar(500) '$.Others',
					Custom_Remarks varchar(500) '$.Custom_Remarks',
					Custom_Status varchar(30) '$.Custom_Status',
					IOR_Status varchar(30) '$.IOR_Status',				
					EOR_Status varchar(30) '$.EOR_Status'
				)  

				delete c from Catalogue.CatalogueHeader a inner join [Catalogue].[CatalogueDetail] b
				on a.CatalogueID=b.CatalogueID inner join Catalogue.CatalogueDocumentDetail c on c.CatalogueDetailID=b.CatalogueDetailID
				where b.CatalogueDetailID=@CatalogueDetailID

				delete c from Catalogue.CatalogueHeader a inner join [Catalogue].[CatalogueDetail] b
				on a.CatalogueID=b.CatalogueID inner join Catalogue.CatalogueImageDetail c
				on c.CatalogueDetailID=b.CatalogueDetailID
				where b.CatalogueDetailID=@CatalogueDetailID
			

				delete from  [Catalogue].[CatalogueDetail] where CatalogueID=@CatalogueID

				Insert into [Catalogue].[CatalogueDetail] (CatalogueID,CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
				HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
				DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,Certificates,Custom_Remarks,
				Custom_Status,
				IOR_Status,EOR_Status,LastModifiedBy,LastModifiedDate)
				select @CatalogueID,CountryID,ProductName,MerchantSKU,ASIN,ProductDescription,
				HSNCode,DeclareValueInDollar,MRPInINR,SellingPriceInINR,ImagePath,
				DocumentPath1,DocumentPath2,DocumentPath3,CTH_HSN,BCD, SWS,IGST,Others,null,Custom_Remarks,
				Custom_Status,
				IOR_Status,EOR_Status, @LoginId, getdate() from #t2  

				SET @CatalogueDetailID=@@IDENTITY

				-- insert of lstCatalogueDocPathDetail
			
				select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId as LastmodifiedBy,
				GETDATE() as lastModifiedDate into #CatalogueDocumentDetail1  from
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				)
				insert into [Catalogue].CatalogueDocumentDetail
				(CatalogueDetailID,DocumentPath,LastModifiedBy,LastModifiedDate)
				select * from #CatalogueDocumentDetail1

				select @CatalogueDetailID CatalogueDetailID, ImagePath,@LoginId as LastmodifiedBy,
				GETDATE() as lastModifiedDate into #CatalogueImageDetail1  from
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)

				insert into [Catalogue].CatalogueImageDetail(CatalogueDetailID,ImagePath,LastModifiedBy,LastModifiedDate)
				select  * from #CatalogueImageDetail1
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from #CatalogueDocumentDetail1)
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from #CatalogueImageDetail1)
		
				-- mail sending to sellers as to
				-- others in cc  
				select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
				@IOREmail=c.email, 
				@EOREmail=v.email from Catalogue.SellerRegistration as sr  
				inner join register.company c on c.companyid=sr.IORPartnerID 
				inner join masters.vendor v on v.vendorid=sr.vendorid  
				where sr.SellerFormID =@SellerFormID

				--custome admins get based on user type 9
				SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
				FROM Register.Users where usertype in ('9')
				set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

				SELECT TOP 1 @CatalogueNumber= CatalogueNumber FROM Catalogue.CatalogueHeader  WHERE  CatalogueID=@CatalogueID  

				exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_ReSend @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 
				
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Updated'
				
				select @Msg as Msg ,cast(1 as bit) as Flag 
				--select 'Catalogue has been updated successfully' as Msg ,cast(1 as bit) as Flag 
			end
			else
			begin  
		
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Error_AlreadyUpdated'
				
				select @Msg as Msg ,cast(0 as bit) as Flag
				--select 'The Catalogue already updated one time. So you can''t update again and again.!' as Msg ,cast(0 as bit) as Flag
			end
		end
	
	commit

end try
begin catch
	if @@TRANCOUNT > 0
	Begin
		rollback;
		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select  @SellerFormID,'Catalogue -'+@Action,@CatalogueNumber,ERROR_MESSAGE(),GETDATE()
		
		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = 'en' and LanguageKey = 'CATALOGUECREATE_SP_CatalogueAction_Failed'
				
		select @Msg as Msg ,cast(0 as bit) as Flag 
	End
end catch

end


GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Check]    Script Date: 11-04-2021 20:41:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Catalogue_Check]  
@SellerFormID int
as
begin
	set nocount on;

	if exists(select 1 from Catalogue.CatalogueHeader  with (nolock)
	where SellerFormID=@SellerFormID )
	Begin
		select cast(1 as bit) as Flag
	End 
	Else
	begin
		select cast(0 as bit) as Flag
	End   
	 

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_HSN_BISDetail]    Script Date: 11-04-2021 20:41:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Catalogue_HSN_BISDetail] 
@CategoryID bigint
as
begin
	set nocount on; 
	 
	select CategoryID, Category, HSNCode, BISCertificateName, BISCertificatePath, 
	cast(IIF(HSNCode is null, 0, 1) as bit) IsHSNUpdated
		--,lstHSNDBCategoryTaxRateMapping = (
		--select HSNDBCategoryTaxRateMappingID,CategoryID,tx.CountryID,c.CountryName,BCD,SWS,TaxRate,StartDate,
		--cast(EndDate as date) EndDate,SpecificDuty,Description
		--from Catalogue.HSNDBCategoryTaxRateMapping tx
		--inner join Masters.Country c
		--on c.CountryID=tx.CountryID
		--where CategoryID=@CategoryID 
		--and getdate() between StartDate and EndDate
		--	for json path
		--)
	from Catalogue.HSNDBCategory
	where CategoryID = @CategoryID and HSNCode is not null  
	for json path, include_null_values, without_array_wrapper
	
	set nocount off;
end 

GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_HSN_Category]    Script Date: 11-04-2021 20:41:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_HSN_Category] 
CREATE procedure [Seller].[usp_Catalogue_HSN_Category] 
as
begin
	set nocount on; 
	 
	select CategoryID,Category from Catalogue.HSNDBCategory with (nolock)
	where ParentID=0
	for json path
	
	set nocount off;
end 

GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_HSN_Keywords]    Script Date: 11-04-2021 20:41:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_HSN_Keywords] 
CREATE procedure [Seller].[usp_Catalogue_HSN_Keywords] 
@ParentID bigint,
@Search varchar(100)=''
as
begin
	set nocount on; 
	 
	With cte
	as
	(
		select CAST( CategoryID as int) as LeafCategoryID,
		CAST( UPPER(LTRIM(RTRIM(Category))) as varchar(4000)) as [Description],
		HeirarchyLevelId,a.ParentID ,a.IsLeafCategory
		from  Catalogue.HSNDBCategory  a  with(nolock) 
		where   IsLeafCategory=1
		and (@ParentID=0 or a.ParentID=@ParentID)
		union all
		select  CAST( cte.LeafCategoryID as int) as LeafCategoryID , 
		CAST(UPPER(LTRIM(RTRIM(a.Category)))+'-->'+UPPER(LTRIM(RTRIM(cte.[Description]))) AS varchar(4000)) [Description],
		a.HeirarchyLevelId,a.ParentID ,a.IsLeafCategory
		from  Catalogue.HSNDBCategory  a  with(nolock) 
		inner join cte on cte.ParentID=a.CategoryID		 
		where (@ParentID=0 or a.ParentID=@ParentID)		
	)
	select distinct top(100)  [Description] as Keyword,LeafCategoryID as CategoryID from cte 
	for json path 
	
	set nocount off;
end 

GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Inventory_Search]    Script Date: 11-04-2021 20:41:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Seller.usp_Catalogue_Inventory_Search 'In Stock','',101
-- Exec Seller.usp_Catalogue_Inventory_Search  @SearchBy='Pending',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Catalogue_Inventory_Search] 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@CompanyDetailID CompanyDetailID
as
begin
	set nocount on;
	 
	-- puneeth query
	--select V1.ASIN Product,MF.[product-name] ProductDesc,F_Qty AvailableQty,U_Qty DefectivePieces,I_Qty InTransitQty,
	--Case when Days_on_Hand<=11 Then 'Limited Stock' when Days_on_Hand=0 then 'Out of Stock' Else 'In Stock' End Status,
	--SoldQty_Last30Days [Last30DaysSales], Days_on_Hand,IIF((((SoldQty_Last30Days/30)*90)-F_Qty)>0,((SoldQty_Last30Days/30)*90)-F_Qty,0) 
	--RecommendedQty,NoOfOffers_AvailableAt_amazon,
	--LowestPriceonAmazon,BuyBox_Price,IsBuyboxWinner BuyBoxStatus 
	--from [10.121.3.65].jenniferreporting.PowerBI.BuyBoxData_Analysis_v1 v1 with(Nolock) 
	--inner Join [10.121.3.65].jenniferreporting.APIRPT.MWSManageFBAInventory MF with(Nolock) on MF.CompanyDetailID=V1.companydetailID 
	--and V1.ASIN=MF.asin and MF.IsActive=1

	declare @AppPath varchar(200)

	select @AppPath = DropDownDescription from Masters.DROPDOWN  with (nolock) where DropdownType='FilePaths' AND DropdownValue='ItemPath'

	SET @APPPATH='https://images-na.ssl-images-amazon.com/images/I/71KoFG3IAEL._UX679_.jpg'

	if(@SearchBy='All')
	begin 
		select @AppPath + ISNULL(ImagePath,'') ImagePath ,Product,ProductDesc,AvailableQty,DefectivePieces,InTransitQty,Status
		,Last30DaySale,DaysOnHand,RecommendedQty,NoOfOffers_AvailableAt_amazon
		,LowestPriceonAmazon,RecommSellingPrice,BuyBoxStatus
		from catalogue.Inventory v1 with(Nolock) 
		left outer join [Product].[Item] I  with (nolock) on i.ItemCode=v1.Product and i.CompanyDetailID=v1.CompanyDetailID
		where v1.CompanyDetailID=@CompanyDetailID
		and (v1.Product LIKE '%' + isnull(@Search,'') + '%')
		for json path
	end
	else
	begin
		select  @AppPath +  ISNULL(ImagePath,'') ImagePath ,Product,ProductDesc,AvailableQty,DefectivePieces,InTransitQty,Status
		,Last30DaySale,DaysOnHand,RecommendedQty,NoOfOffers_AvailableAt_amazon
		,LowestPriceonAmazon,RecommSellingPrice,BuyBoxStatus
		from catalogue.Inventory v1 with(Nolock) 
		left outer join [Product].[Item] I  with (nolock) on i.ItemCode=v1.Product and i.CompanyDetailID=v1.CompanyDetailID
		where v1.CompanyDetailID=@CompanyDetailID
		and (@SearchBy='Limited' and Status='Limited' and (V1.Product LIKE '%' + isnull(@Search,'') + '%') 
		or (@SearchBy='InStock' and Status='InStock'  and (V1.Product LIKE '%' + isnull(@Search,'') + '%') )  
		or (@SearchBy='Outofstock' and Status='Outofstock' and (V1.Product LIKE '%' + isnull(@Search,'') + '%'))  
		)
		for json path
	end

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Search]    Script Date: 11-04-2021 20:41:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_Search] 'all','',142
CREATE procedure [Seller].[usp_Catalogue_Search]
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@SellerFormID int
as
begin
	set nocount on; 

	declare @AppPath varchar(200)

	select @AppPath = DropDownDescription from Masters.DROPDOWN  with (nolock) where DropdownType='FilePaths' AND DropdownValue='CommonPath'
	
	if(@SearchBy='All')
	begin
	
		-- 'https://images-na.ssl-images-amazon.com/images/I/71KoFG3IAEL._UX679_.jpg'

		select @AppPath + ImagePath as ImagePath  , b.CatalogueDetailID,b.CountryID,CountryName as CountryofOrigin,
		ProductName,MerchantSKU,ASIN,ProductDescription,HSNCode,
		STUFF((SELECT '|' + DocumentPath
        FROM  [Catalogue].CatalogueDocumentDetail FOR XML PATH('') ), 1, 1, '') as CatalogueDocumentPath,	
		STUFF((SELECT '|' + ImagePath
        FROM  [Catalogue].CatalogueImageDetail FOR XML PATH('') ), 1, 1, '') as CatalogueImagePath,	
		(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueDocumentDetail ca  with (nolock) 
		where ca.CatalogueDetailID=b.CatalogueDetailID) as DocumentCount,
		(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueImageDetail ca  with (nolock) 
		where ca.CatalogueDetailID=b.CatalogueDetailID) as ImageCount,
		CASE   seller_cataloguestatus when 'Partially Confirm' THEN 'Under Review' 
		WHEN 'Withdrawn' THEN 'Rejected'
		WHEN 'Requested To Resend' THEN 'Request send'
		When 'Under Review' THEN 'Under Review'
		when 'Confirmed' then 'Confirmed'
		when 'Rejected' then 'Rejected'
		END as SellerStatus
		,(select count(CatalogueID) from Catalogue.CatalogueHistory ih  with (nolock) where ih.CatalogueID=a.CatalogueID) as NoOfIssue
		from [Catalogue].[CatalogueHeader] a  with (nolock) 
		inner join [Catalogue].CatalogueDetail b  with (nolock) on a.CatalogueID=b.CatalogueID
		inner join [Catalogue].[SellerRegistration] cd  with (nolock)  on cd.SellerFormID=a.SellerFormID 
		inner join Masters.Country C  with (nolock) on C.CountryID = b.CountryID		
		where a.SellerFormID = @SellerFormID
		and (ProductName like '%' + isnull(@Search,'') + '%' or b.MerchantSKU LIKE '%' + isnull(@Search,'') + '%') 
		order by b.CatalogueDetailID desc
		for json path, include_null_values
	end
	if(@SearchBy='Draft')
	begin
		select Distinct CountryName as CountryName,BatchID,  
		FileName,
		count(isnull(B.CatalogueID,0)) as ProductCount, 
		'Draft' as SellerStatus
		from [Catalogue].[CatalogueHeader_temp] a  with (nolock) 
		inner join [Catalogue].CatalogueDetail_temp b  with (nolock) on a.CatalogueID=b.CatalogueID
		inner join [Catalogue].[SellerRegistration] cd  with (nolock)  on cd.SellerFormID=a.SellerFormID 
		inner join Masters.Country C  with (nolock) on C.CountryID = b.CountryID		
		where a.IsCompleted=0 and a.SellerFormID = @SellerFormID
		and (CountryName like '%' + isnull(@Search,'') + '%' or A.BatchID LIKE '%' + isnull(@Search,'') + '%') 
		GROUp by CountryName,BatchID,FileName
		order by BatchID desc
		for json path, include_null_values
	end
	else
	begin
		select  @AppPath + ImagePath as ImagePath ,b.CatalogueDetailID,b.CountryID,CountryName as CountryofOrigin,
		ProductName,MerchantSKU,ASIN,ProductDescription,HSNCode,
		STUFF((SELECT '|' + DocumentPath
        FROM  [Catalogue].CatalogueDocumentDetail FOR XML PATH('') ), 1, 1, '') as CatalogueDocumentPath,	
		STUFF((SELECT '|' + ImagePath
        FROM  [Catalogue].CatalogueImageDetail FOR XML PATH('') ), 1, 1, '') as CatalogueImagePath,	
		(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueDocumentDetail ca  with (nolock) 
		where ca.CatalogueDetailID=b.CatalogueDetailID) as DocumentCount,
		(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueImageDetail ca  with (nolock) 
		where ca.CatalogueDetailID=b.CatalogueDetailID) as ImageCount,
		CASE   seller_cataloguestatus when 'Partially Confirm' THEN 'Under Review' 
		WHEN 'Withdrawn' THEN 'Rejected'
		WHEN 'Requested To Resend' THEN 'Request send'
		When 'Under Review' THEN 'Under Review'
		when 'Confirmed' then 'Confirmed'
		when 'Rejected' then 'Rejected'
		END as SellerStatus
		,(select count(CatalogueID) from Catalogue.CatalogueHistory ih  with (nolock) where ih.CatalogueID=a.CatalogueID) as NoOfIssue
		from [Catalogue].[CatalogueHeader] a  with (nolock) 
		inner join [Catalogue].CatalogueDetail b  with (nolock) on a.CatalogueID=b.CatalogueID
		inner join [Catalogue].[SellerRegistration] cd  with (nolock)  on cd.SellerFormID=a.SellerFormID 
		inner join Masters.Country C  with (nolock) on C.CountryID = b.CountryID		
		where a.SellerFormID = @SellerFormID
		and (CASE   seller_cataloguestatus when 'Partially Confirm' THEN 'Under Review' 
		WHEN 'Withdrawn' THEN 'Rejected'
		WHEN 'Requested To Resend' THEN 'Request send'
		When 'Under Review' THEN 'Under Review'
		when 'Confirmed' then 'Confirmed'
		when 'Rejected' then 'Rejected'
		END ) =@SearchBy
		and (ProductName like '%' + isnull(@Search,'') + '%' or b.MerchantSKU LIKE '%' + isnull(@Search,'') + '%') 
		order by b.CatalogueDetailID desc
		for json path, include_null_values
	end
	
	set nocount off;
end 



GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_SearchById]    Script Date: 11-04-2021 20:41:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_SearchById] 247,81
CREATE procedure [Seller].[usp_Catalogue_SearchById]
@CatalogueDetailID bigint,
@SellerFormID INT
as
begin
	set nocount on;

	select cd.CatalogueDetailID,cd.CountryID,CountryName as CountryofOrigin,
	ProductName,
	MerchantSKU,ASIN,ProductDescription,HSNCode, 
	CTH_HSN,BCD,
	SWS,IGST,Others,Certificates,Custom_Remarks,Custom_Status,
	STUFF((SELECT '|' + DocumentPath
	FROM  [Catalogue].CatalogueDocumentDetail FOR XML PATH('') ), 1, 1, '') as CatalogueDocumentPath,	
	STUFF((SELECT '|' + ImagePath
	FROM  [Catalogue].CatalogueImageDetail FOR XML PATH('') ), 1, 1, '') as CatalogueImagePath,	
	(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueDocumentDetail ca  with (nolock) 
	where ca.CatalogueDetailID=cd.CatalogueDetailID) as DocumentCount,
	(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueImageDetail ca  with (nolock) 
	where ca.CatalogueDetailID=cd.CatalogueDetailID) as ImageCount,
	CASE   seller_cataloguestatus when 'Partially Confirm' THEN 'Under Review' 
	WHEN 'Withdrawn' THEN 'Rejected'
	WHEN 'Requested To Resend' THEN 'Request send'
	When 'Under Review' THEN 'Under Review'
	when 'Confirmed' then 'Confirmed'
	when 'Rejected' then 'Rejected'
	END as SellerStatus  
	,lstCatalogueHistory=(
	select chl.CatalogueStatus,Remarks,isnull(u.firstname,'') + isnull(u.lastname,'') LastModifiedByName,chl.LastModifiedDate
	,u.UserType UserType
	from   [Catalogue].[CatalogueHeader] as ch  with (nolock) 
	inner join [Catalogue].[CatalogueDetail] as cd  with (nolock) on cd.CatalogueID=ch.CatalogueID 
	inner join [Catalogue].[CatalogueHistory] as chl  with (nolock) on chl.CatalogueID=ch.CatalogueID 
	inner join Register.Users as u  with (nolock)  on u.userid=chl.LastModifiedBy
	where ch.SellerFormID = @SellerFormID and cd.CatalogueDetailID = @CatalogueDetailID
	order by chl.LastModifiedDate desc 
	for json path, include_null_values
	)
	from [Catalogue].[CatalogueHeader] cH  with (nolock) 
	inner join [Catalogue].[CatalogueDetail] as cd  with (nolock) on cd.CatalogueID=ch.CatalogueID
	inner join Catalogue.sellerregistration as cod  with (nolock) on cod.SellerFormID=ch.SellerFormID 
	inner join Masters.Country C  with (nolock) on C.CountryID = cD.CountryID
	where ch.SellerFormID = @SellerFormID and cd.CatalogueDetailID = @CatalogueDetailID 
	for json path, without_array_wrapper, include_null_values

	set nocount off;
end 

 



GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Status]    Script Date: 11-04-2021 20:41:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_Status] 81
CREATE procedure  [Seller].[usp_Catalogue_Status]
@SellerFormID int
as
begin

	select t.SellerStatus,coalesce(temp.StatusCount,t.StatusCount)StatusCount,
	coalesce(temp.LastModifiedDate,t.LastModifiedDate) as LastModifiedDate 
	from (
	Select 'Rejected' as SellerStatus,0 as StatusCount,'' as LastModifiedDate
	union all
	Select 'Request send' as SellerStatus,0 as StatusCount,'' as LastModifiedDate
	union all
	Select 'Under Review' as SellerStatus,0 as StatusCount,'' as LastModifiedDate
	union all
	Select 'Confirmed' as SellerStatus,0 as StatusCount,'' as LastModifiedDate
	union all
	Select 'Draft' as SellerStatus,
	(select count(distinct batchId) from Catalogue.CatalogueHeader_temp with (nolock)
	where SellerFormID=@SellerFormID  and iscompleted=0 ) as StatusCount,'' as LastModifiedDate
	) as t left join 
	(select * from 
	(
	select  SellerStatus, count(SellerStatus) StatusCount,convert(varchar(10), max(LastModifiedDate),103) as LastModifiedDate from 
	(
		select  CASE   seller_cataloguestatus when 'Partially Confirm' THEN 'Under Review' 
		WHEN 'Withdrawn' THEN 'Rejected'
		WHEN 'Requested To Resend' THEN 'Request send'
		When 'Under Review' THEN 'Under Review'
		when 'Confirmed' then 'Confirmed'
		when 'Rejected' then 'Rejected'
		END as SellerStatus,a.LastModifiedDate
		from Catalogue.CatalogueHeader a with (nolock)
		where a.SellerFormID=@SellerFormID  

	) as t group by SellerStatus	 
	) as g) temp on temp.SellerStatus=t.SellerStatus
	order by SellerStatus
	for json path
end

GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Temp_SearchById]    Script Date: 11-04-2021 20:41:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Catalogue_Temp_SearchById] 'A816AAAA-B352-47FA-860B-6D862E308D1A',81
CREATE procedure [Seller].[usp_Catalogue_Temp_SearchById]
@BatchID varchar(50),
@SellerFormID INT
as
begin
	set nocount on;
	 
	select CountryName CountryofOrigin,ProductName,MerchantSKU,ProductDescription,HSNCode
	,(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueDocumentDetail_Temp ca  with (nolock) 
	where ca.CatalogueDetailID=d.CatalogueDetailID) BulkDocCount
	,lstCatalogueDocPathDetail=(
	select isnull (( 
		select DocumentPath DocPath
		from   [Catalogue].CatalogueDocumentDetail_temp as cdoc  with (nolock) 
		inner join [Catalogue].[CatalogueDetail_temp] as cd  with (nolock) on cd.CatalogueDetailID=cdoc.CatalogueDetailID  
		where  cd.CatalogueDetailID = d.CatalogueDetailID 
		for json path ),'[]')
	)
	,(select isnull( count(CatalogueDetailID),0) from  [Catalogue].CatalogueImageDetail_Temp ca  with (nolock) 
	where ca.CatalogueDetailID=d.CatalogueDetailID) BulkImageCount
	,lstCatalogueImagePathDetail=(
	select isnull (( 
		select cdoc.ImagePath ImagePath
		from   [Catalogue].CatalogueImageDetail_temp as cdoc  with (nolock) 
		inner join [Catalogue].[CatalogueDetail_temp] as cd  with (nolock) on cd.CatalogueDetailID=cdoc.CatalogueDetailID  
		where  cd.CatalogueDetailID = d.CatalogueDetailID 
	for json path ),'[]') 
	)
	from [Catalogue].[CatalogueDetail_Temp] D with (nolock) 
	inner join [Catalogue].[CatalogueHeader_Temp] H  with (nolock) on H.CatalogueID = D.CatalogueID
	inner join Masters.Country C  with (nolock) on C.CountryID = D.CountryID
	where h.SellerFormID = @SellerFormID and h.BatchID = @BatchID
	for json path , include_null_values 

	set nocount off;
end 

 



GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Upload_Action]    Script Date: 11-04-2021 20:41:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Catalogue_Upload_Action]
@json varchar(max)
as
begin
begin try
	begin transaction 

		--declare @json varchar(max)

		--set @json='{"lstCatalogueHistory":[],"lstCatalogueImagePathDetail":[],"lstCatalogueDocPathDetail":[],"JsonData":"[{\"CountryofOrigin\":\"INDIA\",\"ProductName\":\"A\",\"MerchantSKU\":\"B\",\"AmazonASIN\":\"C\",\"ProductDescription\":\"D\",\"HSNCode\":\"1234567\",\"lstCatalogueImagePathDetail\":[{\"ImagePath\":\"8d52f0da-ad07-408b-ab67-d939e349de06.png\"}],\"lstCatalogueDocPathDetail\":[],\"BulkImageCount\":1},{\"CountryofOrigin\":\"INDIA\",\"ProductName\":\"B\",\"MerchantSKU\":\"B1\",\"AmazonASIN\":\"B2\",\"ProductDescription\":\"B3\",\"HSNCode\":\"765432\",\"lstCatalogueImagePathDetail\":[{\"ImagePath\":\"1d2efd1c-dcf0-419e-a579-0202c7e11dc8.jpg\"},{\"ImagePath\":\"f8d955bc-0120-4828-b40a-2c5a67f41dfe.jpg\"}],\"lstCatalogueDocPathDetail\":[],\"BulkImageCount\":2}]","LanguageType":"en","SellerFormID":81,"LoginId":165}'
 
		declare @BatchID varchar(50)
		declare @CatalogueID bigint
		declare @CatalogueDetailID bigint
		declare @lstCatalogueDocPathDetail nvarchar(max)
		declare @lstCatalogueImagePathDetail nvarchar(max)
		declare @ImagePath varchar(300)
		declare @SellerFormID int
		declare @CatalogueNumber varchar(30)   
		declare @LoginId  UserID 
		-- MAIL SENDING
		declare @SellerEmail varchar(50)	
		declare @RKSellerID varchar(30)	 
		declare @IOREmail varchar(50)
		declare @EOREmail varchar(50)
		declare @Email_CC varchar(5000)
		declare @MarketPlaceSellerID varchar(30)
		declare @CustomName varchar(100)
		DECLARE @tableHTML  NVARCHAR(MAX) ='<br />'; 

		-- Translation
		declare @LanguageType varchar(10)	
		declare @SuccessMsg nvarchar(1000)   	 
		declare @JsonData varchar(max)
		 
		select  @LoginId=value from openjson(@json) where [key] = 'LoginId'  
		select  @SellerFormID=value from openjson(@json) where [key] = 'SellerFormID'   
		select  @JsonData=value from openjson(@json) where [key] = 'JsonData'  
		 
		select  @LanguageType=value from openjson(@json) where [key] = 'LanguageType'
		 
		if object_id('tempdb..#t1', 'U') is not null
		BEGIN
			drop table  #t1 
		END 
		create table #t1
		(
			SLNo int identity(1,1) not null,
			CountryofOrigin varchar(100) ,
			ProductName varchar(max) ,
			MerchantSKU varchar(max) , 
			ProductDescription varchar(max) ,
			HSNCode varchar(max) , 
			lstCatalogueImagePathDetail nvarchar(max), 
			lstCatalogueDocPathDetail nvarchar(max) ,   
		) 


		INSERT INTO #t1 ( CountryofOrigin,ProductName,MerchantSKU,ProductDescription,HSNCODE,lstCatalogueImagePathDetail,lstCatalogueDocPathDetail)
		select RTRIM(LTRIM(CountryofOrigin)),RTRIM(LTRIM(ProductName)),RTRIM(LTRIM(MerchantSKU)),
		RTRIM(LTRIM(ProductDescription)),RTRIM(LTRIM(HSNCODE)),lstCatalogueImagePathDetail,lstCatalogueDocPathDetail
		from
		openjson(@JsonData) 
		with ( 
			CountryofOrigin varchar(100) '$.CountryofOrigin',
			ProductName varchar(max) '$.ProductName',
			MerchantSKU varchar(max) '$.MerchantSKU', 
			ProductDescription varchar(max) '$.ProductDescription',
			HSNCode varchar(max) '$.HSNCode' ,
			lstCatalogueImagePathDetail nvarchar(max)  AS JSON,   
			lstCatalogueDocPathDetail nvarchar(max)  AS JSON 
		)  
		 
		 
		declare @c int ,@i int
		select @c=count(slno) from #t1

		declare @Action varchar(10) 
		select  @Action=value from openjson(@json) where [key] = 'Action' 


		if(@Action='AI') --Actual Insert
		begin
			 
			set @i=1
			while (@i<=@c)
			begin
				 
				SET @CatalogueNumber =( SELECT TOP 1 CatalogueNumber FROM Catalogue.CatalogueUniqueMaster U
				WHERE NOT EXISTS (SELECT 1 FROM Catalogue.CatalogueHeader AS M WHERE M.CatalogueNumber=U.CatalogueNumber )) 

				
				-- header insert
				Insert into [Catalogue].[CatalogueHeader] (SellerFormID,CatalogueNumber,CatalogueDate,
				Seller_CatalogueStatus,Custom_CatalogueStatus,IOR_CatalogueStatus,EOR_CatalogueStatus,
				LastModifiedBy,LastModifiedDate)
				values (@SellerFormID, @CatalogueNumber, getdate(), 
				'Under Review','New','Under Review','Under Review',
				@LoginId, getdate())
				 
				set @CatalogueID = SCOPE_IDENTITY()

				-- history insert
				Insert into [Catalogue].CatalogueHistory (CatalogueID,CatalogueStatus,Remarks,
				LastModifiedBy,LastModifiedDate)
				values (@CatalogueID, 'New', 'Newly Added',
				@LoginId, getdate()) 
		
				-- details  
				Insert into [Catalogue].[CatalogueDetail] (CatalogueID,CountryID,ProductName,MerchantSKU,ProductDescription,
				HSNCode,LastModifiedBy,LastModifiedDate)
				select distinct @CatalogueID,c.CountryID,ProductName,MerchantSKU,ProductDescription,
				HSNCode,@LoginId, getdate() from #t1 
				inner join masters.Country c on c.countryname=#t1.CountryofOrigin
				where slno=@i 
				 

				set @CatalogueDetailID=SCOPE_IDENTITY()
			 
				-- image and document detail insert 

				select @lstCatalogueImagePathDetail =lstCatalogueImagePathDetail ,
				@lstCatalogueDocPathDetail =lstCatalogueDocPathDetail from #t1 
				where slno=@i  

				select top 1 @ImagePath=ImagePath    from
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)  
				update [Catalogue].[CatalogueDetail] set ImagePath=@ImagePath
				where CatalogueDetailID=@CatalogueDetailID

			   
				insert into [Catalogue].CatalogueImageDetail(CatalogueDetailID,ImagePath,LastModifiedBy,LastModifiedDate)
				select @CatalogueDetailID,ImagePath,@LoginId, getdate() from 
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)

				insert into [Catalogue].CatalogueDocumentDetail
				(CatalogueDetailID,DocumentPath,LastModifiedBy,LastModifiedDate)
				select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId,GETDATE()   
				from
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				)

				-- updating draf files status
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from
				openjson(@lstCatalogueImagePathDetail ) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)) 
			
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from  
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				))


				set @i=@i+1

				-- mail sending others in cc 
				--select  @RKSellerID=RKSellerID,@SellerEmail=sr.Email, 
				--@IOREmail=c.email, 
				--@EOREmail=v.email,@CustomName=c.CompanyName from Catalogue.SellerRegistration as sr  
				--inner join register.company c on c.companyid=sr.IORPartnerID 
				--inner join masters.vendor v on v.vendorid=sr.vendorid  
				--where sr.SellerFormID =@SellerFormID

				----custome admins get based on user type 9
				--SELECT @Email_CC = COALESCE(@Email_CC + ';', '') + CAST(email AS VARCHAR(50))
				--FROM Register.Users where usertype in ('9')
				--set @Email_CC =  isnull(@Email_CC,'') + ';'+ @IOREmail + ';'+ @EOREmail

				--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Seller_New @SellerEmail,@RKSellerID,@CatalogueNumber,@Email_CC 
				--exec catalogue.usp_CrossBorder_Sendmail_Catalogue_Custom_Update @IOREmail,@RKSellerID,@CustomName,
				--@CatalogueNumber,@Email_CC 

			end

			
			select  @BatchID=value from openjson(@json) where [key] = 'BatchID'  
			update [Catalogue].[CatalogueHeader_temp] set IsCompleted=1 where BatchID=@BatchID
			 
			select @SuccessMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Added'
				
			select @SuccessMsg as Msg ,cast(1 as bit) as Flag
			--select 'Catalogue has been added successfully' as Msg ,cast(1 as bit) as Flag  
		end
		else if(@Action='TI') --Temp Insert or update
		begin
			
			
			declare @FileName varchar(300) 
			select  @FileName=value from openjson(@json) where [key] = 'FileName' 

			select  @BatchID=value from openjson(@json) where [key] = 'BatchID'  
			if(isnull(@BatchID,'')='') 
			begin
				set @BatchID=NEWID()
			end
			else
			begin  
				delete cd from [Catalogue].Cataloguehistory_TEMP as cd
				inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
				where BatchID=@BatchID  
				
				delete cdi from [Catalogue].CatalogueImageDetail_TEMP as cdi
				inner join [Catalogue].CatalogueDetail_TEMP  cd on cd.CatalogueDetailID=cd.CatalogueDetailID
				inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
				where BatchID=@BatchID 
				
				delete cdi from [Catalogue].CatalogueDocumentDetail_TEMP as cdi
				inner join [Catalogue].CatalogueDetail_TEMP  cd on cd.CatalogueDetailID=cd.CatalogueDetailID
				inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
				where BatchID=@BatchID 

				delete cd from [Catalogue].CatalogueDetail_TEMP as cd
				inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
				where BatchID=@BatchID
				
				select top 1  @FileName=FileName from [Catalogue].[CatalogueHeader_temp] where BatchID=@BatchID 

				DELETE FROM [Catalogue].CatalogueHEADER_TEMP where BatchID=@BatchID 
				
			end
			set @i=1
			while (@i<=@c)
			begin
				 
				SET @CatalogueNumber =( SELECT TOP 1 CatalogueNumber FROM Catalogue.CatalogueUniqueMaster U
				WHERE NOT EXISTS (SELECT 1 FROM Catalogue.CatalogueHeader AS M WHERE M.CatalogueNumber=U.CatalogueNumber )) 
				 
				-- header insert
				Insert into [Catalogue].[CatalogueHeader_temp] (SellerFormID,CatalogueNumber,CatalogueDate,
				Seller_CatalogueStatus,Custom_CatalogueStatus,IOR_CatalogueStatus,EOR_CatalogueStatus,
				LastModifiedBy,LastModifiedDate,BatchID,IsCompleted,FileName)
				values (@SellerFormID, @CatalogueNumber, getdate(), 
				'Under Review','New','Under Review','Under Review',
				@LoginId, getdate(),@BatchID,0,@FileName)

				set @CatalogueID = SCOPE_IDENTITY()

				-- history insert
				Insert into [Catalogue].CatalogueHistory_temp (CatalogueID,CatalogueStatus,Remarks,
				LastModifiedBy,LastModifiedDate)
				values (@CatalogueID, 'New', 'Newly Added',
				@LoginId, getdate()) 
		
				-- details 
				Insert into [Catalogue].[CatalogueDetail_temp] (CatalogueID,CountryID,ProductName,MerchantSKU,ProductDescription,
				HSNCode,LastModifiedBy,LastModifiedDate)
				select distinct @CatalogueID,c.CountryID,ProductName,MerchantSKU,ProductDescription,
				HSNCode,@LoginId, getdate() from #t1 
				inner join masters.Country c on c.countryname=#t1.CountryofOrigin
				where slno=@i 


				set @CatalogueDetailID=SCOPE_IDENTITY()
			 
				-- image and document detail insert

				select @lstCatalogueImagePathDetail =lstCatalogueImagePathDetail ,
				@lstCatalogueDocPathDetail =lstCatalogueDocPathDetail from #t1 
				where slno=@i  

				select top 1 @ImagePath=ImagePath    from
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)  
				 
				update [Catalogue].[CatalogueDetail_temp] set ImagePath=@ImagePath
				where CatalogueDetailID=@CatalogueDetailID

			   
				insert into [Catalogue].CatalogueImageDetail_temp(CatalogueDetailID,ImagePath,LastModifiedBy,LastModifiedDate)
				select @CatalogueDetailID,ImagePath,@LoginId, getdate() from 
				openjson(@lstCatalogueImagePathDetail) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)

				insert into [Catalogue].CatalogueDocumentDetail_temp
				(CatalogueDetailID,DocumentPath,LastModifiedBy,LastModifiedDate)
				select @CatalogueDetailID CatalogueDetailID, DocPath,@LoginId,GETDATE()   
				from
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				)

				-- updating draf files status
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct ImagePath from
				openjson(@lstCatalogueImagePathDetail ) 
				with (
					ImagePath varchar(300) '$.ImagePath'
				)) 
			
				update Register.AppFile set FileStatus = 'S' where ObjectId in (select distinct DocPath from  
				openjson(@lstCatalogueDocPathDetail) 
				with (
					DocPath varchar(300) '$.DocPath'
				))


				set @i=@i+1 

			end

			select 'Catalogue has been added as draft status' as Msg ,cast(1 as bit) as Flag  
		end
		else if(@Action='TD') --Temp Insert or update
		begin
			
			select  @BatchID=value from openjson(@json) where [key] = 'BatchID'  

			delete cd from [Catalogue].Cataloguehistory_TEMP as cd
			inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
			where BatchID=@BatchID  
				
			delete cdi from [Catalogue].CatalogueImageDetail_TEMP as cdi
			inner join [Catalogue].CatalogueDetail_TEMP  cd on cd.CatalogueDetailID=cd.CatalogueDetailID
			inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
			where BatchID=@BatchID 
				
			delete cdi from [Catalogue].CatalogueDocumentDetail_TEMP as cdi
			inner join [Catalogue].CatalogueDetail_TEMP  cd on cd.CatalogueDetailID=cd.CatalogueDetailID
			inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
			where BatchID=@BatchID 

			delete cd from [Catalogue].CatalogueDetail_TEMP as cd
			inner join [Catalogue].CatalogueHEADER_TEMP  ch on ch.Catalogueid=cd.Catalogueid
			where BatchID=@BatchID 
			DELETE FROM [Catalogue].CatalogueHEADER_TEMP where BatchID=@BatchID 

			if(@@rowcount>0)
			begin
				select 'Drat Catalogue has been added deleted permanently' as Msg ,cast(1 as bit) as Flag
			end
			begin
				select 'No Batch ID' as Msg ,cast(0 as bit) as Flag
			end
		end
	commit 
end try
begin catch
	if @@TRANCOUNT > 0
	Begin
		rollback; 
		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select  @SellerFormID,'Catalogue -'+@Action,@CatalogueNumber,ERROR_MESSAGE(),GETDATE()

		select 'Some validation missing.Please try again sometimes' as Msg ,cast(0 as bit) as Flag 
		--select 'Catalogue not Created. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag
	End
end catch
end

GO

/****** Object:  StoredProcedure [Seller].[usp_Catalogue_Upload_Validate]    Script Date: 11-04-2021 20:41:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Catalogue_Upload_Validate]
@json varchar(max)
as
begin

		declare @SellerFormID int
		declare @CatalogueNumber varchar(30)   
		declare @LoginId  UserID 
		declare @JsonData varchar(max)
		-- MAIL SENDING
		declare @SellerEmail varchar(50)	
		declare @RKSellerID varchar(30)	 
		declare @IOREmail varchar(50)
		declare @EOREmail varchar(50)
		declare @Email_CC varchar(5000)
		declare @MarketPlaceSellerID varchar(30)
		DECLARE @tableHTML  NVARCHAR(MAX) ='<br />'; 

		-- Translation
		declare @LanguageType varchar(10)	
		declare @SuccessMsg nvarchar(1000) 
		declare @FailureMsg nvarchar(1000) 	
		
		declare @NoRecordsMsg nvarchar(1000) 	
		declare @DuplicateCountryMsg nvarchar(1000) 	
		declare @DuplicateMerchantSKUMsg nvarchar(1000) 	
		declare @CountryBlankMsg nvarchar(1000) 	
		declare @InvalidCountryMsg nvarchar(1000) 	
		declare @ProductNameLengthMsg nvarchar(1000) 	
		declare @MerchantSKULengthMsg nvarchar(1000) 	 
		declare @ProductDescriptionLengthMsg nvarchar(1000) 	
		declare @HSNCodeLengthMsg nvarchar(1000) 
		declare @HSNCodeInteger nvarchar(1000)
		declare @MerchantSKUSpaceNotAllowed nvarchar(1000)  	 
		 
		select  @LoginId=value from openjson(@json) where [key] = 'LoginId'  
		select  @SellerFormID=value from openjson(@json) where [key] = 'SellerFormID'   
		select  @JsonData=value from openjson(@json) where [key] = 'JsonData'  
		 
		select  @LanguageType=value from openjson(@json) where [key] = 'LanguageType'
		 
		if object_id('tempdb..#t1', 'U') is not null
		BEGIN
			drop table  #t1 
		END 
		create table #t1
		(
		SLNo int identity(1,1) not null,
		CountryofOrigin varchar(100) ,
		ProductName varchar(max) ,
		MerchantSKU varchar(max) , 
		ProductDescription varchar(max) ,
		HSNCode varchar(max) , 
		IsError bit DEFAULT Null,
		RejectedReason Varchar(2000) DEFAULT Null

		) 


		INSERT INTO #t1 ( CountryofOrigin,ProductName,MerchantSKU,ProductDescription,HSNCODE)
		select RTRIM(LTRIM(CountryofOrigin)),RTRIM(LTRIM(ProductName)),RTRIM(LTRIM(MerchantSKU)),
		RTRIM(LTRIM(ProductDescription)),RTRIM(LTRIM(HSNCODE)) 
		from
		openjson(@JsonData) 
		with ( 
			CountryofOrigin varchar(100) '$.CountryofOrigin',
			ProductName varchar(max) '$.ProductName',
			MerchantSKU varchar(max) '$.MerchantSKU', 
			ProductDescription varchar(max) '$.ProductDescription',
			HSNCode varchar(max) '$.HSNCode' 
		) 
		
		If not exists (select 1 from #t1) 
		Begin 
			select @NoRecordsMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_NoRecords'
				
			SET @tableHTML +=  
			N'<table border="1" class="table table-responsive table-bordered table-condensed">' +  
			N'<tr class="danger">' +    
			N'<th >SLNO</th>' +      
			N'<th >ERROR</th>' +      
			N'</tr>' +  
			CAST ( ( SELECT '',       
			-- neeed slno          
			td = 1, '', 
			td = @NoRecordsMsg, ''  
			FOR XML PATH('tr'), TYPE    
			) AS NVARCHAR(MAX) ) +   
			N'</table>' +  
			N'' ;

			select @tableHTML as Msg ,cast(0 as bit) as Flag 
			
		end
		else
		begin 	
		
			if exists ( select rowss from (
			( select   count( distinct trim(CountryofOrigin)) as rowss from #t1
			)) as t where rowss>1)
			Begin
				select @DuplicateCountryMsg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_DuplicateCountry'
				update #t1 set IsError = 1, RejectedReason = @DuplicateCountryMsg 
				where ltrim(rtrim(isnull(CountryofOrigin,''))) !=''
				--update #t1 set IsError = 1, RejectedReason = 'Duplicate record of CountryofOrigin Field in Excel File'  
				--where ltrim(rtrim(isnull(CountryofOrigin,''))) !=''
			End
			if exists ( select rowss from (
			(select  row_number() over ( partition by MerchantSKU
			order by MerchantSKU) as rowss from #t1)) as t where rowss>1) 
			Begin
				select @DuplicateMerchantSKUMsg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_DuplicateMerchantSKU'
				update #t1 set IsError = 1, RejectedReason = @DuplicateMerchantSKUMsg  
				where ltrim(rtrim(isnull(MerchantSKU,''))) !=''
				--update #t1 set IsError = 1, RejectedReason = 'Duplicate record of MerchantSKU Field in Excel File'  
				--where ltrim(rtrim(isnull(MerchantSKU,''))) !=''
			End 
			
			select @CountryBlankMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType 
			and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_CountryBlank'

			update #t1 set IsError =1,RejectedReason =
			IIF(RejectedReason is null,'', RejectedReason + ' | ') + @CountryBlankMsg
			where ltrim(rtrim(isnull(CountryofOrigin,''))) =''  
			--update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + 'Country of Origin is blank' 
			--where ltrim(rtrim(isnull(CountryofOrigin,''))) =''  
			
			select @InvalidCountryMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_InvalidCountry'
			update L set RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') +''''+isnull(L.CountryofOrigin,'')+''''+ 
			@InvalidCountryMsg,L.IsError = 1 from #t1 L
			where isnull(L.CountryofOrigin,'') not in (select CountryName from Masters.Country  )
			--update L set RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') +''''+isnull(L.CountryofOrigin,'')+''''+ ' is 
			--Invalid CountryofOrigin',L.IsError = 1 from #t1 L
			--where isnull(L.CountryofOrigin,'') not in (select CountryName from Masters.Country where CountryID in (47,114,166,210,160,202))
			 
			select @ProductNameLengthMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 
			'CATALOGUEBULK_SP_CatalogueUpload_Error_ProductNameLength'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + @ProductNameLengthMsg
			where ltrim(rtrim(isnull(ProductName,''))) ='' or Len(ltrim(rtrim(ProductName))) >100 
			
			select @MerchantSKULengthMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_MerchantSKULength'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + @MerchantSKULengthMsg
			where ltrim(rtrim(isnull(MerchantSKU,''))) ='' or Len(ltrim(rtrim(MerchantSKU))) > 100

			select @MerchantSKUSpaceNotAllowed = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_MerchantSKUSpaceNotAllowed'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + @MerchantSKUSpaceNotAllowed
			where Charindex(' ', (TRIM(isnull(MerchantSKU,''))))  !=0
			 
			
			select @ProductDescriptionLengthMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_ProductDescriptionLength'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + @ProductDescriptionLengthMsg
			where ltrim(rtrim(isnull(ProductDescription,'')))=''  or Len(ltrim(rtrim(ProductDescription))) > 500
			--update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + 'Length of ProductDescription is more than 500 characters or it is blank' 
			--where ltrim(rtrim(isnull(ProductDescription,'')))=''  or Len(ltrim(rtrim(ProductDescription))) > 500
			
			select @HSNCodeLengthMsg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_HSNCodeLength'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', RejectedReason + ' | ') + @HSNCodeLengthMsg
			where  Len(ltrim(rtrim(HSNCode))) not  between 4 and 8

			select @HSNCodeInteger = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CATALOGUEBULK_SP_CatalogueUpload_Error_HSNCodeInteger'
			update #t1 set IsError =1,RejectedReason = IIF(RejectedReason is null,'', 
			RejectedReason + ' | ') + @HSNCodeInteger
			where isnumeric(  trim(HSNCode)) !=1 and trim(HSNCode)!='' 

			If exists (select 1 from #t1 where isnull(RejectedReason,'') <> '')
			Begin 
				SET @tableHTML +=  
				N'<table border="1" class="table table-responsive table-bordered table-condensed">' +  
				N'<tr class="danger">' +    
				N'<th >SLNO</th>' +      
				N'<th >ERROR</th>' +      
				N'</tr>' +  
				CAST ( ( SELECT '',       
				-- neeed slno          
				td = SLNo, '', 
				td = RejectedReason, '' 
				from #t1 
				where  IsError = 1
				FOR XML PATH('tr'), TYPE    
				) AS NVARCHAR(MAX) ) +   
				N'</table>' + 
				N'' ;

				select @tableHTML as Msg ,cast(0 as bit) as Flag 
			end
			else
			begin  
				select    'Catalogue has been Validated successfully' as Msg ,cast(1 as bit) as Flag 
			end
		end
	
	
	

end

GO

/****** Object:  StoredProcedure [Seller].[usp_CrossBorder_SellerRegistration_Register]    Script Date: 11-04-2021 20:41:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [Seller].[usp_CrossBorder_SellerRegistration_Register]
@json varchar(max),
@Password binary(32),
@Salt varchar(100)
as 
begin
begin try
	begin transaction 

		set @json=concat('[' ,@json , ']')   
		
		declare @Msg nvarchar(1000)

		declare @RKSellerID varchar(30)  
		declare @CompanyName varchar(200)
		declare @CompanyPhoneNumberCountryCode varchar(5)

		declare @CompanyPhoneNumber varchar(15)
		declare @CountryID tinyint
		declare @CompanyAddress varchar(400)
		declare @BusinessLicense varchar(255)
		declare @ContactPersonName varchar(100)
		declare @Email varchar(50)

		declare @MobileNumberCountryCode varchar(5)
		declare @MobileNumber varchar(15)
		declare @WechatID varchar(50)
		declare @IORPartnerID int
		declare @PSP varchar(100)

		declare @PSPAccountNumber varchar(50)
		declare @VendorID int
		declare @LogisticsPartner varchar(100)
		declare @NoofSKUs int 
		declare @LoginID UserID
		 
		set @CompanyName = JSON_VALUE(@json, '$[0].CompanyName')
		set @CompanyPhoneNumberCountryCode = JSON_VALUE(@json, '$[0].CompanyPhoneNumberCountryCode')

		set @CompanyPhoneNumber = JSON_VALUE(@json, '$[0].CompanyPhoneNumber')
		set @CountryID = JSON_VALUE(@json, '$[0].CountryID')
		set @CompanyAddress = JSON_VALUE(@json, '$[0].CompanyAddress')
		set @BusinessLicense = JSON_VALUE(@json, '$[0].BusinessLicense')
		set @ContactPersonName = JSON_VALUE(@json, '$[0].ContactPersonName')
		set @Email = JSON_VALUE(@json, '$[0].Email')

		set @MobileNumberCountryCode = JSON_VALUE(@json, '$[0].MobileNumberCountryCode')
		set @MobileNumber = JSON_VALUE(@json, '$[0].MobileNumber')
		set @WechatID = JSON_VALUE(@json, '$[0].WechatID')
		set @IORPartnerID = JSON_VALUE(@json, '$[0].IORPartnerID')
		set @PSP = JSON_VALUE(@json, '$[0].PSP')

		set @PSPAccountNumber = JSON_VALUE(@json, '$[0].PSPAccountNumber') 
		set @VendorID = JSON_VALUE(@json, '$[0].VendorID')

		Declare @SelfVendorID int
		set @SelfVendorID=@VendorID
		
		set @LogisticsPartner = JSON_VALUE(@json, '$[0].LogisticsPartner')
		set @NoofSKUs = JSON_VALUE(@json, '$[0].NoofSKUs') 
		set @LoginID = JSON_VALUE(@json, '$[0].LoginId')
		
		declare @LanguageType  varchar(10)
		set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType')

		set @RKSellerID = (select top 1 RKSellerID from Catalogue.RKSellerIDMaster 
		where RKSellerID not in (select   RKSellerID from [Catalogue].[SellerRegistration]))

		if(@VendorID=9999)
		begin
			insert into  Masters.Vendor(CompanyID,VendorName,VendorAliasName,Address1,Address2,City,PostalCode,StateID,
			CountryID,GSTNumber,ContactPerson,ContactNumber,
			Email,IsActive,BankName,BeneficiaryName,AccountNumber,IFSCCode,AccountType,IsCompany,LastModifiedBy,
			LastModifiedDate,IsEOR,IsEORApprovalRequired)
			select 3,@CompanyName+'-Self',@CompanyName,@CompanyAddress,@CompanyAddress,null,null,null,@CountryID,null,
			@ContactPersonName,null,
			@Email,1,null,null,null,null,null,0,1,GETDATE(),0,1

			set @VendorID=@@IDENTITY
		
		end
		if not exists(select 1 from Register.Users where Email = @Email)
		begin

			insert into [Catalogue].[SellerRegistration] (RKSellerID,CompanyName,CompanyPhoneNumberCountryCode,CompanyPhoneNumber,
			CountryID,CompanyAddress, 
			BusinessLicense,ContactPersonName,Email,MobileNumberCountryCode,MobileNumber,
			WechatID,IORPartnerID,PSP,PSPAccountNumber,VendorID,
			LogisticsPartner,NoofSKUs,ApprovalStatus,IsActive,LastModifiedBy,
			LastModifiedDate,CreatedDate)
			values (@RKSellerID,@CompanyName,@CompanyPhoneNumberCountryCode,@CompanyPhoneNumber,@CountryID,@CompanyAddress, 
			@BusinessLicense,@ContactPersonName,@Email,@MobileNumberCountryCode,@MobileNumber,
			@WechatID,@IORPartnerID,@PSP,@PSPAccountNumber,@VendorID,
			@LogisticsPartner,@NoofSKUs,'Pending',1,@LoginID,getdate(),
			getdate())


			declare @SellerFormID int
			set @SellerFormID=scope_identity()

			insert into Seller.Preference (SellerFormID,PreferLanguage,Newstatementgenerated,PaymentreceivedbyPSP,Paymentcomplete
			,Productsrequestedtoresend,Productsapproved,ProductsOutofStock,ShipmentpendingCARPupload,Shipmentrequestedtoresend
			,Shipmentcompleted,Generateandsendreports,LastModifiedBy,LastModifiedDate)
			select @SellerFormID,'EN','Disabled','Disabled','Disabled'
			,'Disabled','Disabled','Disabled','Disabled','Disabled'
			,'Disabled','',1,getdate()

			update Register.AppFile set FileStatus = 'S' where ObjectId = @BusinessLicense

			insert into Register.Users (FirstName, EMail, UserType, Password, Salt, IsActive, LastModifiedBy, LastModifiedDate,SellerFormID)
			values (substring(@Email,0,CHARINDEX('@',@Email)) , @Email, 3, @Password, @Salt, 0, @LoginID, getdate(),@SellerFormID)
			 
			declare @UserId int 
			set @UserId=scope_identity()

			declare @EOREmail varchar(50)
			declare @IOREmail varchar(50)
			declare @EORName varchar(150)
			declare @IsEORApprovalRequired bit
			select @EOREmail=email ,@EORName=VendorName,@IsEORApprovalRequired=IsEORApprovalRequired from masters.vendor where VendorID=@VendorID

			select @IOREmail=email from register.company where companyid=@IORPartnerID
			-- Based on EOR approval sending email with auto approval/ registered email
			if(isnull(@IsEORApprovalRequired,0)=0)
			begin
				--exec Catalogue.usp_CrossBorder_Sendmail_SellerRegistration @Email,@EOREmail,@IOREmail,@RKSellerID,@EORName

				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'usp_CrossBorder_SellerRegistration_Register_Register'
				
				select @Msg as Msg ,cast(1 as bit) as Flag
			end
			else
			begin 
				update [Catalogue].[SellerRegistration] set  
				ApprovalStatus = 'Approved' 
				,ApprovalRemarks = 'Auto Approved'  
				,LastModifiedBy = @LoginID
				,LastModifiedDate = getdate()  where SellerFormID = @SellerFormID

				update Register.Users set IsActive=1,
				LastModifiedBy = @LoginID
				,LastModifiedDate = getdate()
				where email=@Email 

				select @UserId=UserId from Register.Users where email=@email  
			
				insert into register.userpermission (MenuID,UserId,IsViewEdit,LastModifiedBy,LastModifiedDate)
				select distinct menuid,@UserId,'2',@UserId,GETDATE() from register.UserTypeMenu as t where usertype = 3 
				and not exists (select 1 from register.userpermission as m where m.MenuID=t.MenuID and m.userid=@UserId)

				If (@SelfVendorID=9999)

				begin
					insert into register.userpermission (MenuID,UserId,IsViewEdit,LastModifiedBy,LastModifiedDate)
					Select 158,@UserId,'2',@UserId,GETDATE()
					union all
					select 249,@UserId,'2',@UserId,GETDATE()
					union all
					select 250,@UserId,'2',@UserId,GETDATE()
				end
				declare @OrgPassword varchar(6)

				set @OrgPassword=left(@salt,6)

				exec Catalogue.usp_CrossBorder_Sendmail_SellerApprove @Email,@EOREmail,@IOREmail,@RKSellerID,@EORName,@OrgPassword
				 
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'usp_CrossBorder_SellerRegistration_Register_Registeredapproved'
				
				select @Msg as Msg ,cast(1 as bit) as Flag
			end

		end
		else
		begin  
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'usp_CrossBorder_SellerRegistration_Register_Emailexists'
				
			select @Msg as Msg ,cast(0 as bit) as Flag
		end

		commit 
end try
begin catch
	if(@@TRANCOUNT > 0)
	begin
		rollback;

		insert into  Register.ErrorLog(CompanyId,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select  null,'Seller Creation',@Email,ERROR_MESSAGE(),GETDATE()

		select 'Seller not added. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag

		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = @LanguageType and LanguageKey = 'usp_CrossBorder_SellerRegistration_Register_error'
				
		select @Msg as Msg ,cast(0 as bit) as Flag
	end	
end catch
end

GO

/****** Object:  StoredProcedure [Seller].[usp_CrossBorder_SellerRegistration_SearchById]    Script Date: 11-04-2021 20:41:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_CrossBorder_SellerRegistration_SearchById] 99
Create proc [Seller].[usp_CrossBorder_SellerRegistration_SearchById]
@SellerFormID int
as 
begin
	set nocount on;

	select distinct S.SellerFormID, RKSellerID, S.CompanyName, CompanyPhoneNumberCountryCode,	
	CompanyPhoneNumber,	CompanyAddress, BusinessLicense,	ContactPersonName,	S.Email,	
	MobileNumberCountryCode, S.MobileNumber, WechatID, IORPartnerID, C.CompanyName IORPartner, PSP, 	
	PSPAccountNumber, S.VendorID, VendorName, LogisticsPartner,	NoofSKUs, ApprovalStatus, ApprovalRemarks, 
	IsOTPSent, OTPSentDate,	S.MarketPlaceID, MarketPlace, isnull(StoreName, '') StoreName, isnull(MarketPlaceSellerID,'') MarketPlaceSellerID ,	
	MarketPlaceAPIToken, BusinessLaunchDate, S.IsActive ,
	JM.BankName,JM.AccountType,JM.IFSC,AccountName,JM.AccountNumber,JM.IndianGSTNumber,
	JM.GSTState, ISNULL(State,'') StateName, JM.IndianMobileNumber, AssignedDetailDate,
	isnull(IsMobileRequested,0) IsMobileRequested,MobileRequestedDate,isnull(IsCatalogueConfirmed,0) IsCatalogueConfirmed
	,c.CompanySignaturePath,pp.GSTFilePath
	,IsAgreement,AgreementDate
	,registration_link
	,IsPayoneerVerified
	,PayoneerVerifiedDate
	,Co.CountryID
	,Co.CountryName
	from Catalogue.SellerRegistration S with (nolock) 
	left join Register.Company C with (nolock) on C.CompanyID = S.IORPartnerID
	left join Masters.Vendor V with (nolock) on V.VendorID = S.VendorID
	left join Masters.MarketPlace M with (nolock) on M.MarketPlaceID = S.MarketPlaceID
	left join Register.JenniferMobileMaster JM with (nolock) on JM.SellerFormID = s.SellerFormID
	left join Catalogue.PPOB pp with (nolock) on pp.GSTNumber = jm.IndianGSTNumber
	left join Masters.State St with (nolock) on St.StateID = JM.GSTState
	left join Masters.Country co with (nolock) on co.CountryID = s.CountryID	
	where S.SellerFormID = @SellerFormID
	for json path, without_array_wrapper, include_null_values

	set nocount off;
end 

GO

/****** Object:  StoredProcedure [Seller].[usp_Dashboard_Data]    Script Date: 11-04-2021 20:41:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- exec [Seller].[usp_Dashboard_Data]   @SellerFormID
CREATE procedure [Seller].[usp_Dashboard_Data]  
@SellerFormID int
as
begin
	set nocount on;


	  
	declare @TotalShipmentValue  decimal(18,2)
	declare @TotalAmazonCredit decimal(18,2)
	declare @TotalamountReceived  decimal(18,2)
	declare @DutiesTaxesIORInvestments  decimal(18,2)
	declare @Commissions decimal(18,2)
	declare @AdditionalGSTOverflow  decimal(18,2)

	--Bullet Points
	-- Dashboard Total shipment value
	Select @TotalShipmentValue= Sum(ShipmentValue)   
	from Payment.ShipmentTransactions as a with (nolock)
	inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=a.CompanyDetailid
	inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	where sr.SellerFormID=@SellerFormID
	-- Dashboard Total Amazon Credit
	Select @TotalAmazonCredit=Sum(TotalAmt) 
	from Payment.ReceiptsFileUploadLog as a with (nolock)
	inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=a.CompanyDetailid
	inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	where sr.SellerFormID=@SellerFormID
	and totalamt>0 and ReceiptVerifiedBy is not null and  
	Rejected is null  


	Select @TotalamountReceived=Sum(PayableToMerchant)  ,
	@Commissions=Sum(Jennifercommission)+Sum(OtherCommission)+Sum(IORCommission)  ,
	@AdditionalGSTOverflow=Sum(GSToutflow)   ,
	@DutiesTaxesIORInvestments=Sum(PayableToIOR)  
	from Payment.Statements as a with (nolock)
	inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=a.CompanyDetailid
	inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	where sr.SellerFormID=@SellerFormID
  

	declare @TotalShipmentsreachedIndia  decimal(18,2)
	declare @TotalShipmentValueinUSD  decimal(18,2)
	declare @TotalShipmentsinChina decimal(18,2)
	declare @TotalValueinUSD decimal(18,2) 
	
	set @TotalShipmentsreachedIndia=0
	set @TotalShipmentValueinUSD=0
	set @TotalShipmentsinChina=0
	set @TotalValueinUSD=0 

	
	-- TotalShipmentsReachedIndia & Total Value in USD in India
	Select @TotalShipmentsreachedIndia =count(distinct ST.ShipmentNumber),
	@TotalShipmentValueinUSD=Max(ST.ShipmentValue)/Max(CurrencyValue)   from Payment.ShipmentTransactions ST with(Nolock) 
	inner Join Purchase.Shipment PS with(Nolock) on ST.ShipmentNumber=PS.ShipmentNumber 
	Inner Join Purchase.Invoice II with(Nolock) on II.POID=PS.POID
	inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=II.CompanyDetailid
	inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	where sr.SellerFormID=@SellerFormID
	group by  St.companydetailID,II.CurrencyType


	--- Total Shipments in China & Totalvalue in USD
	select @TotalShipmentsinChina=Count(distinct FBAShipmentID)  ,@TotalValueinUSD=Sum(ID.UnitPerPriceInUSD * Qty)   
	from  Catalogue.InvoiceDetail ID with (nolock) 
	Inner Join  Catalogue.InvoiceHeader IH with (nolock) on ID.InvoiceHeaderID=IH.InvoiceHeaderID
	Inner Join Catalogue.PackageHeader PH With(nolock) on PH.PackageHeaderID=IH.PackageHeaderID
	Inner Join Catalogue.SellerRegistration SR With(nolock) on SR.SellerFormID=IH.SellerFormID
	Left Join Register.CompanyDetail CD With(Nolock) on CD.MarketPlaceSellerID=SR.MarketPlaceSellerID  
	Where sr.SellerFormID=@SellerFormID  and not exists (Select ShipmentNumber from Payment.ShipmentTransactions ST With(Nolock)
	Where ST.ShipmentNumber=PH.FBAShipmentID and CD.CompanyDetailID=ST.CompanydetailID) 
	and PH.STNInvoiceStatus='APPROVED' 
	Group by SR.SellerFormID,CD.CompanyDetailID


	select 
	'A' AColumn
	,objBulletvalues = (
	select ISNULL((
	select
	@TotalShipmentValue TotalShipmentValue ,
	@TotalAmazonCredit TotalAmazonCredit ,
	@TotalamountReceived TotalamountReceived 
	for json path--,without_array_wrapper
	),'[]') 
	)
	,objTotalDeductions  = (
	select ISNULL((
	select
	@DutiesTaxesIORInvestments DutiesTaxesIORInvestments ,
	@Commissions Commissions ,
	@AdditionalGSTOverflow AdditionalGSTOverflow 
	for json path --,without_array_wrapper
	),'[]') 
	)
	,lstGrossSales=(
		select ISNULL((
		select * from (
			Select 'THISYEAR' FilterType,Month(purchaseDate) SlNo,
			FORMAT (purchaseDate, 'MMM-yy ') Date,Sum(GMS) SalesValue 
			from [10.121.3.65].Jenniferreporting.PowerBI.SalesData ps with(Nolock) 
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			Where sr.SellerFormID=@SellerFormID and Year(purchaseDate)=Year(Getdate())  
			Group by FORMAT (purchaseDate, 'MMM-yy '),Month(purchaseDate) 
			Union all
			Select 'THISMONTH' DDType,Day(purchaseDate) SlNo,FORMAT (purchaseDate, 'dd-MMM-yy ') Date,Sum(GMS) SalesValue 
			from [10.121.3.65].Jenniferreporting.PowerBI.SalesData ps with(Nolock)  
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			Where sr.SellerFormID=@SellerFormID and Year(purchaseDate)=Year(Getdate()) 
			and Month(purchaseDate)=Month(Getdate())   
			Group by FORMAT (purchaseDate, 'dd-MMM-yy '),Day(purchaseDate)
			Union all
			Select 'LAST30DAYS' DDType,FORMAT (purchaseDate, 'MMddyy') SlNo,FORMAT (purchaseDate, 'dd-MMM-yy ') Date,Sum(GMS) SalesValue 
			from [10.121.3.65].Jenniferreporting.PowerBI.SalesData as ps with(Nolock) 
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			Where sr.SellerFormID=@SellerFormID and Convert(Date,purchaseDate,23)>Convert(date,getdate()-30,23)   
			Group by FORMAT (purchaseDate, 'dd-MMM-yy '),FORMAT (purchaseDate, 'MMddyy')
			Union all
			Select 'LASTMONTH' DDType,Day(purchaseDate) SlNo,FORMAT (purchaseDate, 'dd-MMM-yy ') Date,Sum(GMS) SalesValue 
			from [10.121.3.65].Jenniferreporting.PowerBI.SalesData as ps with(Nolock) 
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			Where sr.SellerFormID=@SellerFormID and Year(purchaseDate)=Year(EOMONTH(DATEADD(month, -1, Current_timestamp))) 
			and Month(purchaseDate)=Month(EOMONTH(DATEADD(month, -1, Current_timestamp)))   
			Group by FORMAT (purchaseDate, 'dd-MMM-yy '),Day(purchaseDate)
			union all
			Select 'CUSTOM_UPTO180DAYS' DDType,Day(purchaseDate) SlNo,FORMAT (purchaseDate, 'dd-MMM-yy ') Date,Sum(GMS) SalesValue 
			from [10.121.3.65].Jenniferreporting.PowerBI.SalesData as ps with(Nolock)
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			Where sr.SellerFormID=@SellerFormID and  purchaseDate between '' and ''   
			Group by FORMAT (purchaseDate, 'dd-MMM-yy '),Day(purchaseDate) 
		) as a 
		for json path
		 ),'[]')
	 )
	 ,lstActivity=(
		select ISNULL((
			select FilterType,ActionDate,ActionMsg from (
			-- catalogue
			select 'Catalogue' FilterType, Max(chi.LastModifiedDate) ActionDate,
			convert(varchar(10),Count(che.CatalogueID))+' '+'New Catalogues have been '+chi.CatalogueStatus +'.' ActionMsg 
			from catalogue.catalogueheader che with(Nolock)
			inner join catalogue.cataloguehistory chi  with (nolock) on chi.CatalogueID=che.CatalogueID
			where SellerFormID=@SellerFormID and chi.CatalogueStatus in ('CatalogueStatus','Confirmed','New'
			,'Partially Confirm','Re-Updated','Rejected'
			,'Resend To Merchant','Resent','Updated','Withdrawn')
			and convert(date,chi.LastModifiedDate,23) >= convert(date,getdate()-7,23)
			group by chi.CatalogueStatus
			union all
			-- Packages
			select 'Package' FilterType,Max(chi.CreatedDate) ActionDate,
			convert(varchar(10),Count(che.PackageHeaderID))+' '+'New Packages have been '+chi.PackageHeaderStatus +'.' ActionMsg 
			from catalogue.packageheader che with(Nolock)
			inner join catalogue.packagehistory chi  with (nolock) on chi.PackageHeaderID=che.PackageHeaderID
			where SellerFormID=@SellerFormID and chi.PackageHeaderStatus in ('Completed', 'Deleted','Pending')
			and convert(date,chi.CreatedDate,23) >= convert(date,getdate()-1117,23)
			group by chi.PackageHeaderStatus
			union all
			-- payments 
			select 'Payment' FilterType,Max(StatementDate) ActionDate,
			convert(varchar(10),Count(StatementNumber))+' '+'New Statement have been generated.' ActionMsg from Payment.Statements PS with(Nolock)
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			where sr.SellerFormID=@SellerFormID and convert(date,StatementDate,23) >= convert(date,getdate()-7,23)
			group by PS.CompanyDetailID,StatementDate having Count(StatementNumber)>1
			union all
			select 'Payment' FilterType,Max(Convert(date,Approved_On,23)) ActionDate,  
			convert(varchar(10),Count(StatementNumber))+' '+'New Statement have been Approved and It will be Moved to Disbursements.' ActionMsg    
			from Payment.Statements PS with(Nolock)
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			where sr.SellerFormID=@SellerFormID AND convert(date,Approved_On,23) >= convert(date,getdate()-7,23)
			group by PS.CompanyDetailID,Convert(date,Approved_On,23) having Count(StatementNumber)>1
			Union all
			select 'Payment' FilterType,Max(Convert(date,PSP_PaymentDateToSeller,23)) ActionDate, 
			convert(varchar(10),Count(StatementNumber))+' '+'Statements disbursement have been completed.' ActionMsg   
			from Payment.Statements PS with(Nolock)
			inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
			inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
			where sr.SellerFormID=@SellerFormID AND PSP_PaymentDateToSeller is not null 
			and  convert(date,PSP_PaymentDateToSeller,23) >= convert(date,getdate()-7,23)
			group by PS.CompanyDetailID,Convert(date,PSP_PaymentDateToSeller,23) having Count(StatementNumber)>1
			)  as a for json path 
		 ),'[]')
	 )
	 ,lstTop5Product=(
		select ISNULL(( 
		Select Top 5 row_number() over ( order by asin desc ) SLNO ,ASIN, ProductName, 
		Sum(Case When Year(purchaseDate)=Year(Getdate()) and Month(purchaseDate)=Month(Getdate())   
		Then GMS End) CurrentMonth, Sum(GMS) YTDSales 
		from [10.121.3.65].Jenniferreporting.PowerBI.SalesData as ps with(Nolock)
		inner join Register.CompanyDetail cd  with (nolock) on cd.CompanyDetailid=PS.CompanyDetailid
		inner join catalogue.sellerregistration sr  with (nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
		where sr.SellerFormID=@SellerFormID and purchaseDate>=DATEADD(yy, DATEDIFF(yy, 0, GETDATE()), 0)
		Group by  ASIN, productName Order by CurrentMonth Desc
		for json path 
		 ),'[]')
	 )
	,objMyShipment  = (
	select ISNULL((
	select 
	@TotalShipmentsreachedIndia TotalShipmentsReachedIndia ,
	@TotalShipmentValueinUSD TotalShipmentValueinUSD ,
	@TotalShipmentsinChina TotalShipmentsinChina , 
	@TotalValueinUSD TotalValueinUSD  
	for json path --,without_array_wrapper
	),'[]') 
	)
	for json path,without_array_wrapper 
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_FAQ_Search]    Script Date: 11-04-2021 20:41:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create procedure [Seller].[usp_FAQ_Search] 
@Search varchar(100) = '',
@SellerFormID int,
@LoginID int
as
begin
	set nocount on;
	 
	select FAQID,Category,Question,Answer
	from Seller.FAQ with (nolock)
	where IsActive = 1 and 
	((Question like '%' + isnull(@Search,'') + '%')
	or (Category like '%' + isnull(@Search,'') + '%') 
	)
	for json path

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_OnBoarding_Check]    Script Date: 11-04-2021 20:41:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- exec Seller.usp_OnBoarding_Check 81
CREATE procedure [Seller].[usp_OnBoarding_Check]  
@SellerFormID int
as
begin
	set nocount on;


	--declare @SellerFormID int  
	--set @SellerFormID =81

	--6 - Catalogue Not available
	--7 - Catalogue not Reviewed
	--8 - Agreement not done
	--9	- Store Creation not done
	--10 - Final Thank You   
	--1000 -- Welcome or Dashboard page 

	-- Catalogue Not available 
	if not exists(select 1 from Catalogue.CatalogueHeader  with (nolock)
	where SellerFormID=@SellerFormID)
	begin
		update Catalogue.SellerRegistration set OnBoardingNumber=6
		where SellerFormID=@SellerFormID 

		select 6
	end 
	else
	begin
		-- Catalogue not Reviewed
		declare @CatalogueID int 
		declare @Seller_CatalogueStatus varchar(100)  
		select top 1 @CatalogueID=CatalogueID,@Seller_CatalogueStatus=Seller_CatalogueStatus from Catalogue.CatalogueHeader  with (nolock)
		where SellerFormID=@SellerFormID
		order by CatalogueID asc 
		if(@Seller_CatalogueStatus!='Confirmed')
		begin
			update Catalogue.SellerRegistration set OnBoardingNumber=7
			where SellerFormID=@SellerFormID

			select 7
		end 
		else
		begin
			--Agreement not done	
			if exists(select 1 from Catalogue.SellerRegistration  with (nolock)
			where SellerFormID=@SellerFormID AND ISNULL(IsAgreement,0)=0)
			begin
				update Catalogue.SellerRegistration set OnBoardingNumber=8
				where SellerFormID=@SellerFormID

				select 8
			end 
			else
			begin
				--Store Creation not done
				if exists(select 1 from Catalogue.SellerRegistration  with (nolock)
				where SellerFormID=@SellerFormID AND ISNULL(MarketPlaceSellerID,'')='')
				begin
					update Catalogue.SellerRegistration set OnBoardingNumber=9
					where SellerFormID=@SellerFormID 

					select 9
				end 
				else
				begin
					-- Dashboard screen
					update Catalogue.SellerRegistration set OnBoardingNumber=1000
					where SellerFormID=@SellerFormID

					select 1000
				end
			end
		end
	end
	
	set nocount off; 
end 

GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Action]    Script Date: 11-04-2021 20:41:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Seller].[usp_Package_Action] 
@json VARCHAR(max) 
AS 
BEGIN 
	BEGIN try 
	BEGIN TRAN 
	SET nocount ON; 
      --declare @json varchar(max) 
      --set @json='' 

	  
	DECLARE @var   VARCHAR(200),           
	@MaxDBNumber VARCHAR(30), 
	@Sequence    VARCHAR(50) 
	DECLARE		@i INT 
	Declare		@Sequence1    VARCHAR(50) 

	SET @json=Concat('[' ,@json , ']') 
	DECLARE @Action            VARCHAR(10) 
	DECLARE @PackageHeaderID   BIGINT 
	DECLARE @SellerFormID      INT 
	DECLARE @FBAShipmentID     VARCHAR(30) 
	DECLARE @LogisticPartnerID BIGINT 
	DECLARE @CountryID         INT 
	DECLARE @ShipFrom          INT 
	DECLARE @ShipTo            INT 
	DECLARE @LoginId    INT 
	DECLARE @lstPackageDetail  VARCHAR(max) 
	DECLARE @lstInvoiceHeader  VARCHAR(max) 

	declare @Msg nvarchar(1000)
	declare @LanguageType varchar(10)

	SET @Action=Json_value(@json,'$[0].Action'); 
	SET @SellerFormID=Json_value(@json,'$[0].SellerFormID'); 
	SET @FBAShipmentID=Json_value(@json,'$[0].FBAShipmentID'); 
	SET @LogisticPartnerID=Json_value(@json,'$[0].LogisticPartnerID'); 
	SET @CountryID=Json_value(@json,'$[0].CountryID'); 
	SET @ShipFrom=Json_value(@json,'$[0].ShipFrom'); 
	SET @ShipTo=Json_value(@json,'$[0].ShipTo'); 
	SET @LoginId=Json_value(@json,'$[0].LoginId'); 
	SET @lstPackageDetail=Json_query(@json,'$[0].lstPackageDetail'); 
	SET @lstInvoiceHeader=Json_query(@json,'$[0].lstInvoiceHeader'); 
	Declare @STNNumber varchar(30)
	SET @STNNumber=Json_value(@json,'$[0].STNNumber'); 
	Declare @STNDate datetime
	SET @STNDate=Json_value(@json,'$[0].STNDate'); 
	set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType')
	--Invoice declaration 
	DECLARE @InvoiceHeaderID  BIGINT 
	DECLARE @BuyerOrderNo     VARCHAR(30) 
	DECLARE @BuyerOrderDate   DATETIME 
	DECLARE @ConsignorID      INT 
	DECLARE @ConsigneeID      INT 
	DECLARE @Aircraft         VARCHAR(100) 
	DECLARE @From             VARCHAR(100) 
	DECLARE @SailingOnOrAbout VARCHAR(200) 
	DECLARE @ShippingRemarks  VARCHAR(200) 
	DECLARE @TermsOfDelivery  VARCHAR(10) 
	DECLARE @InvoiceDate      DATETIME 
	DECLARE @lstInvoiceDetail VARCHAR(max) 
	DECLARE @ModeOfShipment VARCHAR(50)
	SET @ModeOfShipment=Json_value(@json,'$[0].ModeOfShipment'); 
	IF(@Action='G')
	  Begin
				--FBAShipmentID is InvoiceNumber
				
				declare @InvoiceNumber varchar(30)
				SET @InvoiceNumber=Json_value(@json,'$[0].InvoiceNo');
				
				SET @lstInvoiceDetail=Json_query(@json,'$[0].lstInvoiceDetail');
				select id.* into #t1 from
				Openjson ( @lstInvoiceDetail ) 
				WITH ( 
					unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' 
				) as id

				 --Calculation
				declare @TotalInvoiceValue decimal(18,2)
				declare @PerInvoiceMinLimitInUSD decimal(18,2)
				set @PerInvoiceMinLimitInUSD=(select PerInvoiceMinLimitInUSD from Catalogue.USDPricingMaster)
				declare @PerInvoiceMaxLimitInUSD decimal(18,2)
				set @PerInvoiceMaxLimitInUSD=(select PerInvoiceMaxLimitInUSD+PerInvoiceMaxPermissibleLimitinUSD
				from Catalogue.USDPricingMaster)
				declare @PerInvoiceMaxLimWithOutPermiLimitInUSD decimal(18,2)
				set @PerInvoiceMaxLimWithOutPermiLimitInUSD=(select PerInvoiceMaxLimitInUSD from Catalogue.USDPricingMaster)
				
				set @TotalInvoiceValue=(select sum(unitperpriceinusd*qty) from  Openjson ( @lstInvoiceDetail ) 
					WITH ( 
					unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
					qty int '$.Qty' 
					)
				)

				if exists(select   1 from Openjson ( @lstInvoiceDetail )
				WITH ( 
				unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' 
				) 
				as id where id.unitperpriceinusd >@PerInvoiceMaxLimWithOutPermiLimitInUSD )
				Begin
					select @Msg = LanguageError from [Register].[Language_Key] 
					where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_G_Error_InvoiceValueGreater'

					SELECT @Msg+cast(@PerInvoiceMaxLimWithOutPermiLimitInUSD as varchar(10))+'$.' AS Msg , Cast(0 AS BIT) AS flag 
				End
				else if(@TotalInvoiceValue>@PerInvoiceMaxLimitInUSD)
				BEGIN
				
				--Splitting
					delete from catalogue.ConsolidatedInvoice where FBAShipmentID=@InvoiceNumber
					INSERT INTO catalogue.ConsolidatedInvoice (FBAShipmentID,CatalogueDetailID,UnitPerPriceInUSD,Qty,LastModifiedBy,LastModifiedDate)
					SELECT @InvoiceNumber, cataloguedetailid, unitperpriceinusd,qty, @LoginId,Getdate()  				
					FROM   Openjson ( @lstInvoiceDetail ) 
					WITH ( 
					cataloguedetailid bigint '$.CatalogueDetailID' , 
					unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
					qty int '$.Qty' )
					
					SELECT  'SUCCESS' AS Msg , Cast(1 AS BIT) AS Flag
					
				
				END
				else if(@TotalInvoiceValue<@PerInvoiceMinLimitInUSD)
				Begin
					select @Msg = LanguageError from [Register].[Language_Key] 
					where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_G_Error_InvoiceValueLess'

					SELECT @Msg+cast(@PerInvoiceMinLimitInUSD as varchar(10))+'$.' AS Msg , Cast(0 AS BIT) AS flag 
				End 
				else
				Begin
					delete from catalogue.ConsolidatedInvoice where FBAShipmentID=@InvoiceNumber
					INSERT INTO catalogue.ConsolidatedInvoice (FBAShipmentID,CatalogueDetailID,UnitPerPriceInUSD,Qty,LastModifiedBy,LastModifiedDate)
					SELECT @InvoiceNumber, cataloguedetailid, unitperpriceinusd,qty, @LoginId,Getdate()  				
					FROM   Openjson ( @lstInvoiceDetail ) 
					WITH ( 
					cataloguedetailid bigint '$.CatalogueDetailID' , 
					unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
					qty int '$.Qty' )
					SELECT  'SUCCESS' AS Msg , Cast(1 AS BIT) AS Flag
				End
			
			
				
	  End

	IF(@Action='I') 
	BEGIN   

		--deleting temp table or invoice table for avoid duplication	

		delete Ci from  catalogue.ConsolidatedInvoice    as ci
		inner join catalogue.packageheader_temp as ph on ph.FBAShipmentID=ci.FBAShipmentID
		where ph.SellerFormID=@SellerFormID and ci.FBAShipmentID =@FBAShipmentID

		DELETE  FROM   catalogue.invoicedetail 
		WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader as a 
		inner join catalogue.packageheader_temp   as b on b.PackageHeaderID=a.PackageHeaderID
		where b.SellerFormID=@SellerFormID and b.FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.invoiceheader    WHERE   PackageHeaderID in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packagedetail_temp WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.PackageHistory_temp  WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packageheader_temp  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID

		SELECT @MaxDBNumber = 
		( SELECT Cast (Isnull(Cast( 
		( SELECT TOP(1) 
		dbo.Udf_getnumeric( packagenumber) 
		FROM     catalogue.packageheader a 
		ORDER BY 1 DESC) AS INT),0)+1 AS VARCHAR(10))) 
		SELECT @var= 
		CASE Len(@MaxDBNumber) 
		WHEN 1 THEN '000000'+@MaxDBNumber 
		WHEN 2 THEN '00000' +@MaxDBNumber 
		WHEN 3 THEN '0000'  +@MaxDBNumber 
		WHEN 4 THEN '000'   +@MaxDBNumber 
		WHEN 5 THEN '00'    +@MaxDBNumber 
		WHEN 6 THEN '0'     +@MaxDBNumber 
		ELSE @MaxDBNumber 
		END 
		SELECT @Sequence='PRK'+@var 

		IF NOT EXISTS   (  SELECT 1  FROM   catalogue.packageheader     WHERE  lastmodifieddate=Getdate()   AND    packagenumber=@Sequence) 
		BEGIN 

			INSERT INTO catalogue.packageheader  
			(PackageDate,SellerFormID,FBAShipmentID,PackageNumber,LogisticPartnerID,
			CountryID,ShipFrom,ShipTo,
			STNInvoiceStatus,CARPStatus,BOEStatus,CheckListStatus,PODStatus,FinalStatus,
			IsActive,CreatedBy,CreatedDate,LastModifiedBy,LastModifiedDate,STNNumber,STNDate,ModeOfShipment)
			VALUES (  Getdate(), @SellerFormID,@FBAShipmentID,  @Sequence,@LogisticPartnerID,
			@CountryID,@ShipFrom, @ShipTo,
			'Pending','Pending', 'Pending','Pending', 'Pending','Pending',
			1,@LoginId,Getdate(), @LoginId,Getdate() , @STNNumber,@STNDate,@ModeOfShipment) 



			SET @PackageHeaderID=Scope_identity() 

			IF NOT EXISTS (  SELECT 1  FROM   catalogue.packagedetail  WHERE  packageheaderid=@PackageHeaderID) 
			BEGIN 
				INSERT INTO catalogue.packagedetail (PackageHeaderID,CatalogueDetailID,MRPInINR,Qty,BoxQty,WeightQty,LastModifiedBy,LastModifiedDate,FNSKU)
				SELECT @PackageHeaderID, cataloguedetailid, mrpininr, qty, boxqty,weightqty, @LoginId,Getdate(),FNSKU
				FROM   Openjson ( @lstPackageDetail ) 
				WITH 
				( cataloguedetailid bigint '$.CatalogueDetailID' , 
				mrpininr decimal(18,2) '$.MRPInINR' , 
				qty int '$.Qty' , 
				boxqty int '$.BoxQty' ,
				weightqty decimal(18,2) '$.WeightQty' ,
				FNSKU varchar(30)'$.FNSKU' 
				)
			END 

			--Invoice Generation  
			SET @i=0 
			WHILE(@i< ( SELECT Isnull(Count(*),0) FROM   Openjson(@lstInvoiceHeader))) 
			BEGIN 
				SET @BuyerOrderNo=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderNo');
				SET @BuyerOrderDate=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderDate');
				SET @ConsignorID=Json_value(@lstInvoiceHeader,'$[0].ConsignorID');
				SET @ConsigneeID=Json_value(@lstInvoiceHeader,'$[0].ConsigneeID');
				SET @InvoiceDate=Getdate() 
				SET @Aircraft=Json_value(@lstInvoiceHeader,'$[0].Aircraft');
				SET @From=Json_value(@lstInvoiceHeader,'$[0].From');
				SET @SailingOnOrAbout=Json_value(@lstInvoiceHeader,'$[0].SailingOnOrAbout');
				SET @ShippingRemarks=Json_value(@lstInvoiceHeader,'$[0].ShippingRemarks')
				SET @TermsOfDelivery=Json_value(@lstInvoiceHeader,'$[0].TermsOfDelivery');
					
				SET @lstInvoiceDetail=Json_query(@lstInvoiceHeader,'$[' +Cast(@i AS VARCHAR(10))+'].lstInvoiceDetail');
					
				SELECT @Sequence1=@FBAShipmentID+ case  len(cast(@i+1 as varchar(10))) when 1 then '0'+cast(@i+1 as varchar(10)) else cast(@i+1 as varchar(10)) end
				IF NOT EXISTS  ( SELECT 1 FROM catalogue.invoiceheader	WHERE  
				lastmodifieddate=Getdate()	AND    invoiceno=@Sequence1) 
				BEGIN 
					INSERT INTO catalogue.invoiceheader (SellerFormID,PackageHeaderID,InvoiceNo,InvoiceDate,BuyerOrderNo
					,BuyerOrderDate,ConsignorID,ConsigneeID,Aircraft,[From],SailingOnOrAbout,ShippingRemarks,TermsOfDelivery,DocketNumber,ShipmentFilePath1
					,ShipmentDate,ShipmentUpdatedBy,ShipmentRemarks,CheckListID,CheckListDate,CheckListUpdatedBy,CheckListFilePath1,ChecklistStatus
					,CheckListRemarks,BOEID,BOENumber,BOEDate,BOEUpdatedBy,BOEFilePath1,BOEStatus,BOERemarks,IsActive,Created_By
					,Created_Date,LastModifiedBy,LastModifiedDate)
					VALUES  ( 
					@SellerFormID,@PackageHeaderID,@Sequence1, @InvoiceDate, trim(@BuyerOrderNo),
					@BuyerOrderDate,@ConsignorID,@ConsigneeID,trim(@Aircraft),trim( @From),
					trim(@SailingOnOrAbout),trim(@ShippingRemarks), @TermsOfDelivery,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1, @LoginId,
					Getdate(),@LoginId,Getdate()                        
					) 

					SET @InvoiceHeaderID=Scope_identity() 
					IF NOT EXISTS ( 	SELECT 1 FROM  catalogue.invoicedetail WHERE  invoiceheaderid=@InvoiceHeaderID 
					) 
					BEGIN 
						INSERT INTO catalogue.invoicedetail (InvoiceHeaderID,CatalogueDetailID,UnitPerPriceInUSD,Qty,LastModifiedBy,LastModifiedDate)
						SELECT @InvoiceHeaderID, cataloguedetailid, unitperpriceinusd,qty, @LoginId,Getdate()  				
						FROM   Openjson ( @lstInvoiceDetail ) 
						WITH ( 
						cataloguedetailid bigint '$.CatalogueDetailID' , 
						unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
						qty int '$.Qty' )
						END 
					END 
            
					SET @i=@i+1
				END

			--End of while loop
			--STN Log
			Insert into catalogue.STNInvoiceApproval
			select @PackageHeaderID,'Pending','',@LoginId,getdate()
			--Package Log
			Insert into catalogue.PackageHistory
			select @PackageHeaderID,'Pending','',@LoginId,getdate()

			--select @Msg = LanguageError from [Register].[Language_Key] 
			--where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Insert'
				
			--select @Msg as Msg ,cast(1 as bit) as Flag
			SELECT 'Your shipment has been uploaded succesfully.
			Please give 48 hours to review all your products.' AS Msg , Cast(1 AS BIT) AS flag 
		END 
	END 
	IF(@Action='U') 
	BEGIN 
		If not exists(select 1 from Catalogue.PackageHeader p where p.PackageHeaderID=@PackageHeaderID and p.FinalStatus='Completed')
		Begin
			SET @PackageHeaderID=Json_value(@json,'$[0].PackageHeaderID');
			 
			-- delete from temp  table with invoice  
			If exists(select 1 from Catalogue.PackageHeader_temp p where SellerFormID=@SellerFormID and p.FBAShipmentID=@FBAShipmentID)
			Begin
				delete Ci from  catalogue.ConsolidatedInvoice    as ci
				inner join catalogue.packageheader   as ph on ph.FBAShipmentID=ci.FBAShipmentID
				where ph.SellerFormID=@SellerFormID  and ph.FBAShipmentID=@FBAShipmentID

				DELETE  FROM   catalogue.invoicedetail 
				WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader as a 
				inner join catalogue.packageheader_temp     as b on b.PackageHeaderID=a.PackageHeaderID
				where b.SellerFormID=@SellerFormID   and FBAShipmentID=@FBAShipmentID)

				DELETE FROM   catalogue.invoiceheader  WHERE   PackageHeaderID in (select a.PackageHeaderID from catalogue.PackageHeader_temp   as a  
				where SellerFormID=@SellerFormID   and FBAShipmentID=@FBAShipmentID)

				DELETE FROM   catalogue.packagedetail_temp WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.PackageHeader_temp as a  
				where SellerFormID=@SellerFormID   and FBAShipmentID=@FBAShipmentID)

				DELETE FROM   catalogue.PackageHistory_temp    WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.PackageHeader_temp as a  
				where SellerFormID=@SellerFormID  and FBAShipmentID=@FBAShipmentID)

				DELETE FROM   catalogue.packageheader_temp    
				where SellerFormID=@SellerFormID  and FBAShipmentID=@FBAShipmentID 

			end
			-- insert if not exists in the actual table 
			if not exists( select 1 from Catalogue.PackageHeader p where SellerFormID=@SellerFormID and p.FBAShipmentID=@FBAShipmentID)
			begin

				INSERT INTO catalogue.packageheader  
				(PackageDate,SellerFormID,FBAShipmentID,PackageNumber,LogisticPartnerID,
				CountryID,ShipFrom,ShipTo,
				STNInvoiceStatus,CARPStatus,BOEStatus,CheckListStatus,PODStatus,FinalStatus,
				IsActive,CreatedBy,CreatedDate,LastModifiedBy,LastModifiedDate,STNNumber,STNDate,ModeOfShipment)
				VALUES (  Getdate(), @SellerFormID,@FBAShipmentID,  @Sequence,@LogisticPartnerID,
				@CountryID,@ShipFrom, @ShipTo,
				'Pending','Pending', 'Pending','Pending', 'Pending','Pending',
				1,@LoginId,Getdate(), @LoginId,Getdate() , @STNNumber,@STNDate,@ModeOfShipment)

				SET @PackageHeaderID=Scope_identity() 

			end

			UPDATE catalogue.packageheader 
			SET    packagedate= Getdate(), sellerformid =@SellerFormID, fbashipmentid= @FBAShipmentID, logisticpartnerid= @LogisticPartnerID, 
					countryid= @CountryID, shipfrom= @ShipFrom, ShipTo= @ShipTo, carpstatus= 'Pending', checkliststatus= 'Pending', boestatus='Pending', 
					podstatus= 'Pending' , finalstatus= 'Pending', isactive=1, lastmodifiedby= @LoginId, lastmodifieddate= Getdate() 
					,ModeOfShipment=@ModeOfShipment
			WHERE  packageheaderid=@PackageHeaderID 

			--Delete and Insert operation in PackageDetail 
			UPDATE catalogue.packagedetail 
			SET    lastmodifiedby=@LoginId, lastmodifieddate=Getdate() 
			WHERE  packageheaderid=@PackageHeaderID 

			DELETE FROM   catalogue.packagedetail WHERE  packageheaderid=@PackageHeaderID 

			INSERT INTO catalogue.packagedetail (PackageHeaderID,CatalogueDetailID,MRPInINR,Qty
			,BoxQty,WeightQty,LastModifiedBy,LastModifiedDate,FNSKU)
			SELECT @PackageHeaderID, cataloguedetailid,  mrpininr,  qty,
			boxqty, weightqty,  @LoginId, Getdate() ,FNSKU
			FROM   Openjson ( @lstPackageDetail ) 
			WITH ( 
				cataloguedetailid bigint '$.CatalogueDetailID' , 
				mrpininr decimal(18,2) '$.MRPInINR' , 
				qty int '$.Qty' , 
				boxqty int '$.BoxQty' , 
				weightqty decimal(18,2) '$.WeightQty',
				FNSKU varchar(30) '$.FNSKU'
			)
		 
			--Invoice delete Insert
			 
			Update catalogue.InvoiceHeader 
			SET    lastmodifiedby=@LoginId, 
				lastmodifieddate=Getdate() 
				WHERE  PackageHeaderID=@PackageHeaderID 
			UPDATE id
			SET    lastmodifiedby=@LoginId, 
				lastmodifieddate=Getdate() 
				from Catalogue.InvoiceHeader ih
				inner join Catalogue.InvoiceDetail id
				on id.InvoiceHeaderID=ih.InvoiceHeaderID
			WHERE  ih.PackageHeaderID=@PackageHeaderID

			DELETE id  from Catalogue.InvoiceHeader ih
				inner join Catalogue.InvoiceDetail id
				on id.InvoiceHeaderID=ih.InvoiceHeaderID
			WHERE  ih.PackageHeaderID=@PackageHeaderID

			Delete  Catalogue.InvoiceHeader WHERE  PackageHeaderID=@PackageHeaderID 
				

			DECLARE @j INT 
			SET @j=0 
			WHILE(@j< ( SELECT Isnull(Count(*),0) FROM   Openjson(@lstInvoiceHeader))) 
			BEGIN 
				SET @BuyerOrderNo=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderNo');
				SET @BuyerOrderDate=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderDate');
				SET @ConsignorID=Json_value(@lstInvoiceHeader,'$[0].ConsignorID');
				SET @ConsigneeID=Json_value(@lstInvoiceHeader,'$[0].ConsigneeID');
				SET @InvoiceDate=Getdate() 
				SET @Aircraft=Json_value(@lstInvoiceHeader,'$[0].Aircraft');
				SET @From=Json_value(@lstInvoiceHeader,'$[0].From');
				SET @SailingOnOrAbout=Json_value(@lstInvoiceHeader,'$[0].SailingOnOrAbout');
				SET @ShippingRemarks=Json_value(@lstInvoiceHeader,'$[0].ShippingRemarks')
				SET @TermsOfDelivery=Json_value(@lstInvoiceHeader,'$[0].TermsOfDelivery');
					
				SET @lstInvoiceDetail=Json_query(@lstInvoiceHeader,'$[' +Cast(@j AS VARCHAR(10))+'].lstInvoiceDetail');
				Declare @Sequence2    VARCHAR(50) 
					
				SELECT @Sequence2=@FBAShipmentID+ case  len(cast(@j+1 as varchar(10))) when 1 then '0'+cast(@j+1 as varchar(10)) else cast(@j+1 as varchar(10)) end
				
				IF NOT EXISTS  ( SELECT 1 FROM catalogue.invoiceheader	WHERE  
				lastmodifieddate=Getdate()	AND    invoiceno=@Sequence2) 
				BEGIN 

					INSERT INTO catalogue.invoiceheader (SellerFormID,PackageHeaderID,InvoiceNo,InvoiceDate,BuyerOrderNo
					,BuyerOrderDate,ConsignorID,ConsigneeID,Aircraft,[From],SailingOnOrAbout,ShippingRemarks,TermsOfDelivery,DocketNumber,ShipmentFilePath1
					,ShipmentDate,ShipmentUpdatedBy,ShipmentRemarks,CheckListID,CheckListDate,CheckListUpdatedBy,CheckListFilePath1,ChecklistStatus
					,CheckListRemarks,BOEID,BOENumber,BOEDate,BOEUpdatedBy,BOEFilePath1,BOEStatus,BOERemarks,IsActive,Created_By
					,Created_Date,LastModifiedBy,LastModifiedDate)
					VALUES  ( 
					@SellerFormID,@PackageHeaderID,@Sequence2, @InvoiceDate, trim(@BuyerOrderNo),
					@BuyerOrderDate,@ConsignorID,@ConsigneeID,trim(@Aircraft),trim( @From),
					trim(@SailingOnOrAbout),trim(@ShippingRemarks), @TermsOfDelivery,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1, @LoginId,
					Getdate(),@LoginId,Getdate()   ) 

					SET @InvoiceHeaderID=Scope_identity() 

					IF NOT EXISTS (SELECT 1 FROM  catalogue.invoicedetail WHERE  invoiceheaderid=@InvoiceHeaderID ) 
					BEGIN 
						INSERT INTO catalogue.invoicedetail (InvoiceHeaderID,CatalogueDetailID,UnitPerPriceInUSD,Qty,LastModifiedBy,LastModifiedDate)
						SELECT @InvoiceHeaderID, cataloguedetailid, unitperpriceinusd,qty, @LoginId,Getdate()  				
						FROM   Openjson ( @lstInvoiceDetail ) 
						WITH ( 
						cataloguedetailid bigint '$.CatalogueDetailID' , 
						unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
						qty int '$.Qty' )
						END 
					END 
            
					SET @j=@j+1
			END
		
			--Checklist status to pending
			IF EXISTS ( SELECT 1 FROM   catalogue.checklistapproval a WHERE  a.PackageHeaderID=@PackageHeaderID) 
			BEGIN 
				update catalogue.checklistapproval set CreatedBy=@LoginId,CreatedDate=getdate()
				delete from catalogue.checklistapproval where PackageHeaderID=@PackageHeaderID 
				INSERT INTO catalogue.checklistapproval (PackageHeaderID,CheckListID,ChecklistStatus,CheckListRemarks,CreatedBy,CreatedDate)
				SELECT @PackageHeaderID,checklistid,'Pending' AS checkliststatus,'' AS checklistremarks,@LoginId,Getdate() 
				FROM   catalogue.checklistapproval 
				WHERE  PackageHeaderID=@PackageHeaderID 
			END
			--BOE Status to pending
			IF EXISTS ( SELECT 1 FROM   catalogue.boeapproval a WHERE  a.PackageHeaderID=@PackageHeaderID) 
			BEGIN 
				update catalogue.boeapproval set CreatedBy=@LoginId,CreatedDate=getdate()
				delete from catalogue.boeapproval where PackageHeaderID=@PackageHeaderID 
				INSERT INTO catalogue.boeapproval(PackageHeaderID,BOEID,BOENumber,BOEStatus,BOERemarks,CreatedBy,CreatedDate)
				SELECT @PackageHeaderID,boeid,boenumber, 'Pending' AS boestatus, ''  AS boeremarks, @LoginId,Getdate() 
				FROM   catalogue.boeapproval 
				WHERE  PackageHeaderID=@PackageHeaderID 
			END   
			--STNINVOICE log
			IF EXISTS ( SELECT 1 FROM   catalogue.STNInvoiceApproval a WHERE  a.PackageHeaderID=@PackageHeaderID) 
			BEGIN 
				update Catalogue.PackageHeader set STNInvoiceStatus='Pending' where PackageHeaderID=@PackageHeaderID
				INSERT INTO catalogue.STNInvoiceApproval(PackageHeaderID,STNInvoiceStatus,Remarks,LastModifiedBy,LastModifiedDate) 
				SELECT @PackageHeaderID,'Pending' AS STNInvoiceStatus, 	'' AS Remarks,@LoginId, Getdate() 
				FROM   catalogue.STNInvoiceApproval 
				WHERE  PackageHeaderID=@PackageHeaderID 
			END 

			--STN/Invoice log
			Insert into catalogue.STNInvoiceApproval
			select @PackageHeaderID,'Pending','',@LoginId,getdate()

			--Package Log
			Insert into catalogue.PackageHistory(PackageHeaderID,PackageHeaderStatus,PackageHeaderRemarks,CreatedBy,CreatedDate)
			select @PackageHeaderID,'Pending','',@LoginId,getdate()

			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Update'
				
			select @Msg as Msg ,cast(1 as bit) as Flag
				--SELECT 'Package details updated successfully' AS msg , Cast(1 AS BIT) AS flag 
			end
		else
		begin
		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Update_Error_Completed'
				
		select @Msg as Msg ,cast(0 as bit) as Flag
		--select 'Package is already completed.So you can'' edit now.!' as Msg ,cast(0 as bit) as Flag
		end
	END 
	IF(@Action='D') 
	BEGIN 
		If not exists(select 1 from Catalogue.PackageHeader p where p.PackageHeaderID=@PackageHeaderID and p.FinalStatus='Completed')
		Begin
			SET @PackageHeaderID=Json_value(@json,'$[0].PackageHeaderID'); 
			SET @SellerFormID=Json_value(@json,'$[0].SellerFormID'); 
		 
			if exists (select 1 from  catalogue.packageheader where packageheaderid=@PackageHeaderID  and SellerFormID=@SellerFormID
			and STNInvoiceStatus='Pending')
			begin

				--Invoice Delete
				UPDATE catalogue.invoicedetail 
				SET    lastmodifiedby=@LoginId, 
						lastmodifieddate=Getdate() 
				WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader where PackageHeaderID=@PackageHeaderID )

				DELETE  FROM   catalogue.invoicedetail 
				WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader where PackageHeaderID=@PackageHeaderID )

				UPDATE catalogue.invoiceheader 
				SET    lastmodifiedby= @LoginId, 
						lastmodifieddate= Getdate() 
				WHERE  PackageHeaderID=@PackageHeaderID 

				DELETE FROM   catalogue.invoiceheader WHERE   PackageHeaderID=@PackageHeaderID

					--Package Delete
				UPDATE catalogue.packagedetail  
				SET    lastmodifiedby=@LoginId,                
						lastmodifieddate=Getdate() 
				WHERE  packageheaderid=@PackageHeaderID 
				DELETE FROM   catalogue.packagedetail WHERE  packageheaderid=@PackageHeaderID 

				UPDATE catalogue.packageheader 
				SET    lastmodifiedby= @LoginId, 
						lastmodifieddate= Getdate() 
				WHERE  packageheaderid=@PackageHeaderID and SellerFormID=@SellerFormID

				DELETE FROM   catalogue.packageheader  WHERE  packageheaderid=@PackageHeaderID  and SellerFormID=@SellerFormID 
        
				Insert into catalogue.PackageHistory(PackageHeaderID,PackageHeaderStatus,PackageHeaderRemarks,CreatedBy,CreatedDate)
				select @PackageHeaderID,'Deleted','',@LoginId,getdate()
				Insert into catalogue.STNInvoiceApproval
					select @PackageHeaderID,'Deleted','',@LoginId,getdate()

				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Delete'
				
				select @Msg as Msg ,cast(1 as bit) as Flag
			--SELECT 'Package details deleted successfully' AS msg , Cast(1 AS BIT) AS flag 
			end
			else
			begin
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Delete_Error_PartiallyApproved'
				
				select @Msg as Msg ,cast(0 as bit) as Flag
				--SELECT 'Package details partially approved. So you can''t delete now.!' AS msg , Cast(0 AS BIT) AS flag 
			end 
		end
		else
		begin
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Update_Error_Completed'
				
			select @Msg as Msg ,cast(0 as bit) as Flag
			--select 'Package is already completed.So you can'' delete now.!' as Msg ,cast(0 as bit) as Flag
		end
	END 
	IF(@Action='DI') -- Draft Insert 
	BEGIN 

		delete Ci from  catalogue.ConsolidatedInvoice    as ci
		inner join catalogue.packageheader_temp as ph on ph.FBAShipmentID=ci.FBAShipmentID
		where ph.SellerFormID=@SellerFormID and ci.FBAShipmentID =@FBAShipmentID

		DELETE  FROM   catalogue.invoicedetail 
		WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader as a 
		inner join catalogue.packageheader_temp   as b on b.PackageHeaderID=a.PackageHeaderID
		where b.SellerFormID=@SellerFormID and b.FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.invoiceheader    WHERE   PackageHeaderID in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packagedetail_temp WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.PackageHistory_temp  WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packageheader_temp  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID

		SELECT @MaxDBNumber = 
		( SELECT Cast (Isnull(Cast( 
		( SELECT TOP(1) 
		dbo.Udf_getnumeric( packagenumber) 
		FROM     catalogue.packageheader_temp a 
		ORDER BY 1 DESC) AS INT),0)+1 AS VARCHAR(10))) 
		SELECT @var= 
		CASE Len(@MaxDBNumber) 
		WHEN 1 THEN '000000'+@MaxDBNumber 
		WHEN 2 THEN '00000' +@MaxDBNumber 
		WHEN 3 THEN '0000'  +@MaxDBNumber 
		WHEN 4 THEN '000'   +@MaxDBNumber 
		WHEN 5 THEN '00'    +@MaxDBNumber 
		WHEN 6 THEN '0'     +@MaxDBNumber 
		ELSE @MaxDBNumber 
		END 
		SELECT @Sequence='PRK'+@var 

		IF NOT EXISTS   (  SELECT 1  FROM   catalogue.packageheader_temp     
		WHERE  lastmodifieddate=Getdate()   AND    packagenumber=@Sequence) 
		BEGIN 
			INSERT INTO catalogue.packageheader_temp  
			(PackageDate,SellerFormID,FBAShipmentID,PackageNumber,LogisticPartnerID,
			CountryID,ShipFrom,ShipTo,
			STNInvoiceStatus,CARPStatus,BOEStatus,CheckListStatus,PODStatus,FinalStatus,
			IsActive,CreatedBy,CreatedDate,LastModifiedBy,LastModifiedDate,STNNumber,STNDate,ModeOfShipment)
			VALUES (Getdate(), @SellerFormID,@FBAShipmentID,  @Sequence,@LogisticPartnerID,
			@CountryID,@ShipFrom, @ShipTo,
			'Pending','Pending', 'Pending','Pending', 'Pending','Pending',
			1,@LoginId,Getdate(), @LoginId,Getdate() , @STNNumber,@STNDate,@ModeOfShipment) 

			SET @PackageHeaderID=Scope_identity() 

			IF NOT EXISTS (  SELECT 1  FROM   catalogue.packagedetail_temp  WHERE  packageheaderid=@PackageHeaderID) 
			BEGIN 
				INSERT INTO catalogue.packagedetail_temp (PackageHeaderID,CatalogueDetailID,MRPInINR,Qty,BoxQty,WeightQty,LastModifiedBy,LastModifiedDate,FNSKU)
				SELECT @PackageHeaderID, cataloguedetailid, mrpininr, qty, boxqty,weightqty, @LoginId,Getdate(),FNSKU
				FROM   Openjson ( @lstPackageDetail ) 
				WITH 
				( cataloguedetailid bigint '$.CatalogueDetailID' , 
				mrpininr decimal(18,2) '$.MRPInINR' , 
				qty int '$.Qty' , 
				boxqty int '$.BoxQty' ,
				weightqty decimal(18,2) '$.WeightQty' ,
				FNSKU varchar(30)'$.FNSKU' 
				)
			END 

			--Invoice Generation 
			SET @i=0 
			WHILE(@i< ( SELECT Isnull(Count(*),0) FROM   Openjson(@lstInvoiceHeader))) 
			BEGIN 
				SET @BuyerOrderNo=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderNo');
				SET @BuyerOrderDate=Json_value(@lstInvoiceHeader,'$[0].BuyerOrderDate');
				SET @ConsignorID=Json_value(@lstInvoiceHeader,'$[0].ConsignorID');
				SET @ConsigneeID=Json_value(@lstInvoiceHeader,'$[0].ConsigneeID');
				SET @InvoiceDate=Getdate() 
				SET @Aircraft=Json_value(@lstInvoiceHeader,'$[0].Aircraft');
				SET @From=Json_value(@lstInvoiceHeader,'$[0].From');
				SET @SailingOnOrAbout=Json_value(@lstInvoiceHeader,'$[0].SailingOnOrAbout');
				SET @ShippingRemarks=Json_value(@lstInvoiceHeader,'$[0].ShippingRemarks')
				SET @TermsOfDelivery=Json_value(@lstInvoiceHeader,'$[0].TermsOfDelivery');
					
				SET @lstInvoiceDetail=Json_query(@lstInvoiceHeader,'$[' +Cast(@i AS VARCHAR(10))+'].lstInvoiceDetail');
					
					
				SELECT @Sequence1=@FBAShipmentID+ case  len(cast(@i+1 as varchar(10))) when 1 then '0'+cast(@i+1 as varchar(10)) else cast(@i+1 as varchar(10)) end
				IF NOT EXISTS  ( SELECT 1 FROM catalogue.invoiceheader	WHERE  
				lastmodifieddate=Getdate()	AND    invoiceno=@Sequence1) 
				BEGIN 
					INSERT INTO catalogue.invoiceheader (SellerFormID,PackageHeaderID,InvoiceNo,InvoiceDate,BuyerOrderNo
					,BuyerOrderDate,ConsignorID,ConsigneeID,Aircraft,[From],SailingOnOrAbout,ShippingRemarks,TermsOfDelivery,DocketNumber,ShipmentFilePath1
					,ShipmentDate,ShipmentUpdatedBy,ShipmentRemarks,CheckListID,CheckListDate,CheckListUpdatedBy,CheckListFilePath1,ChecklistStatus
					,CheckListRemarks,BOEID,BOENumber,BOEDate,BOEUpdatedBy,BOEFilePath1,BOEStatus,BOERemarks,IsActive,Created_By
					,Created_Date,LastModifiedBy,LastModifiedDate)
					VALUES  ( 
					@SellerFormID,@PackageHeaderID,@Sequence1, @InvoiceDate, trim(@BuyerOrderNo),
					@BuyerOrderDate,@ConsignorID,@ConsigneeID,trim(@Aircraft),trim( @From),
					trim(@SailingOnOrAbout),trim(@ShippingRemarks), @TermsOfDelivery,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1, @LoginId,
					Getdate(),@LoginId,Getdate()                        
					) 
					SET @InvoiceHeaderID=Scope_identity() 
					IF NOT EXISTS ( 	SELECT 1 FROM  catalogue.invoicedetail WHERE  invoiceheaderid=@InvoiceHeaderID 
					) 
					BEGIN 
						INSERT INTO catalogue.invoicedetail (InvoiceHeaderID,CatalogueDetailID,UnitPerPriceInUSD,Qty,LastModifiedBy,LastModifiedDate)
						SELECT @InvoiceHeaderID, cataloguedetailid, unitperpriceinusd,qty, @LoginId,Getdate()  				
						FROM   Openjson ( @lstInvoiceDetail ) 
						WITH ( 
						cataloguedetailid bigint '$.CatalogueDetailID' , 
						unitperpriceinusd decimal(18,2) '$.UnitPerPriceInUSD' , 
						qty int '$.Qty' )
						END 
					END 
            
					SET @i=@i+1
				END
			--End of while loop 

			--Package Log
			Insert into catalogue.PackageHistory_temp
			select @PackageHeaderID,'Pending','',@LoginId,getdate() 

			select 'Shipment Details has been saved as Draft.' as Msg ,cast(1 as bit) as Flag
	END 
	END 
	IF(@Action='DD') -- Draft Delete
	BEGIN 

		--DELETE  FROM   catalogue.invoicedetail 
		--WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader where PackageHeaderID=@PackageHeaderID )

		--DELETE FROM   catalogue.invoiceheader WHERE   PackageHeaderID=@PackageHeaderID

		--DELETE FROM   catalogue.packagedetail_temp WHERE  packageheaderid=@PackageHeaderID  

		--DELETE FROM   catalogue.PackageHistory_temp  WHERE  packageheaderid=@PackageHeaderID   

		--DELETE FROM   catalogue.packageheader_temp  WHERE  packageheaderid=@PackageHeaderID  and SellerFormID=@SellerFormID 

		delete Ci from  catalogue.ConsolidatedInvoice    as ci
		inner join catalogue.packageheader_temp as ph on ph.FBAShipmentID=ci.FBAShipmentID
		where ph.SellerFormID=@SellerFormID and ci.FBAShipmentID =@FBAShipmentID

		DELETE  FROM   catalogue.invoicedetail 
		WHERE  invoiceheaderid in (select invoiceheaderid from catalogue.invoiceheader as a 
		inner join catalogue.packageheader_temp   as b on b.PackageHeaderID=a.PackageHeaderID
		where b.SellerFormID=@SellerFormID and b.FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.invoiceheader    WHERE   PackageHeaderID in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packagedetail_temp WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.PackageHistory_temp  WHERE  packageheaderid in (select a.PackageHeaderID from catalogue.packageheader_temp as a  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID)

		DELETE FROM   catalogue.packageheader_temp  
		where SellerFormID=@SellerFormID and FBAShipmentID =@FBAShipmentID

		 
		select 'Shipment Details has been deleted.' as Msg ,cast(1 as bit) as Flag
	END
	COMMIT 
    END try 
	BEGIN catch 
      IF @@TRANCOUNT > 0 
      BEGIN 
        ROLLBACK; 

        INSERT INTO register.errorlog ( companyid, screenname, uniquenumber, errormessage, createddate ) 
        SELECT NULL,  'Package details',  @Sequence, Error_message(), Getdate() 

		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = @LanguageType and LanguageKey = 'PACKAGESELLER_SP_PackageAction_Failed'
				
		select @Msg as Msg ,cast(0 as bit) as Flag
        --SELECT 'Package details not added. Please try again after sometime.!' AS Msg , Cast(0 AS BIT) AS flag 
      END 
    END catch 
END

GO

/****** Object:  StoredProcedure [Seller].[usp_Package_AmazonCatalogueByFBAShipmentId]    Script Date: 11-04-2021 20:41:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Package_AmazonCatalogueByFBAShipmentId]
@json VARCHAR(max) 
as
begin
	set nocount on;

	--declare @json VARCHAR(max)  

	--set @json='{"lstPackageDetail":[{"CatalogueDetailID":0,"CompanyDetailID":31,"SellerFormID":81,"ProductName":null,"MerchantSKU":"MBC_Redmi8A3GB_64GB_SWHT_2021","ProductDescription":null,"HSNCode":null,"ASIN":null,"FNSKU":"X00172VA6V","BoxQty":24.0,"Qty":480.0}],"lstShipTo":[{"DestinationFulfillmentCenterId":"DEL4","CompanyDetailID":31,"SellerFormID":81,"ShipToID":0,"ShipToName":null,"ShipToAddress":null,"ShipFromID":0,"ShipFromName":null,"ShipFromAddress":null}]}'
	 

	if object_id('tempdb..#Temppack', 'U') is not null
	BEGIN
		drop table  #Temppack 
	END 

	if object_id('tempdb..#Destination', 'U') is not null
	BEGIN
		drop table  #Destination 
	END 

	declare @lstPackageDetail varchar(max) 
	Select @lstPackageDetail=value from openjson(@Json) where [key]='lstPackageDetail'

	declare @lstShipTo varchar(max) 
	Select @lstShipTo=value from openjson(@Json) where [key]='lstShipTo'


	select * into #Temppack from 
	Openjson ( @lstPackageDetail ) 
	WITH ( 
	CompanyDetailID int '$.CompanyDetailID' ,  
	SellerFormID int '$.SellerFormID' ,  
	MerchantSKU varchar(100) '$.MerchantSKU' , 
	FNSKU varchar(100) '$.FNSKU' , 
	BoxQty decimal(18,2) '$.BoxQty' ,  
	Qty decimal(18,2) '$.Qty' )

	select * into #Destination from 
	Openjson ( @lstShipTo ) 
	WITH ( 
	CompanyDetailID int '$.CompanyDetailID' ,  
	SellerFormID int '$.SellerFormID' ,  
	DestinationFulfillmentCenterId varchar(100) '$.DestinationFulfillmentCenterId'   ) 


	 
	select 
	'A' AColumn,
	lstPackageDetail=(
		select ISNULL(( 
		select T.*
		from (
		select row_number() OVER( partition by IOR_CatalogueStatus, t.MerchantSKU order by t.MerchantSKU ,CatalogueDetailID desc)
		CatalogueRow,  isnull(CatalogueDetailID,0)  CatalogueDetailID,		
		a.ProductName,a.ASIN,b.CatalogueNumber,a.HSNCode
		,t.MerchantSKU
		,t.FNSKU
		,t.BoxQty
		,t.Qty
		,0 MRPInINR
		,0 WeightQty from #Temppack t 
		left outer join Catalogue.CatalogueDetail a WITH(NOLOCK) on t.MerchantSKU=a.MerchantSKU 
		left outer join Catalogue.CatalogueHeader b	WITH(NOLOCK) on a.CatalogueID=b.CatalogueID and t.SellerFormID=b.SellerFormID
		and b.IOR_CatalogueStatus='Confirmed'
		where b.SellerFormID is not null
		) as t 
		where t.CatalogueRow=1
		for json path , include_null_values 
		 ),'[]')
	),
	lstShipTo=(
		select ISNULL((
		select  distinct
		a.LocationID as ShipToID,a.LocationName as ShipToName,a.Address1 as ShipToAddress,		
		b.CompanyName  as ShipFromName ,pp.PPOBID as ShipFromID,pp.Address1 as ShipFromAddress
		from masters.Location a with(nolock) 
		inner join register.company b with(nolock) on a.CompanyID=b.CompanyID 
		inner join Catalogue.PPOB pp with(nolock) on pp.StateID=a.StateID and pp.CompanyID=a.CompanyID 
		inner join Catalogue.SellerRegistration s on s.IORPartnerID=b.CompanyID and pp.GSTNumber=a.GSTNumber	
		inner join #Destination d on d.DestinationFulfillmentCenterId= a.LocationName and d.SellerFormID=s.SellerFormID
		where a.isactive=1  --and s.SellerFormID=@Parameter1 
		for json path
		 ),'[]')
	 )
	for json path,without_array_wrapper
	 

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Carp_Action]    Script Date: 11-04-2021 20:41:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE [Seller].[usp_Package_Carp_Action]  
@json varchar(max)
as
BEGIN 
Begin Try
	Begin Tran   
	
	set nocount on;

	--declare @json varchar(max)
	--set @json=''

	set @json=concat('[' ,@json , ']')    
	declare @Action varchar(10)
	declare @LoginId bigint
	declare @CARPID	bigint	
	declare @PackageHeaderID	bigint	 
	declare @AppointmentID	varchar(30)
	declare @AppointmentDate	datetime	 
	declare @FromTime	time
	declare @ToTime	time
	declare @FilePath1 varchar(300)
				
	declare @Msg nvarchar(1000)
	declare @LanguageType varchar(10)

	SET @Action=JSON_VALUE(@json,'$[0].Action');
	SET @PackageHeaderID=JSON_VALUE(@json,'$[0].PackageHeaderID');	
	SET @AppointmentID=JSON_VALUE(@json,'$[0].AppointmentID');  
	SET @AppointmentDate=JSON_VALUE(@json,'$[0].AppointmentDate');  	
	SET @FromTime=JSON_VALUE(@json,'$[0].FromTime');  
	SET @ToTime=JSON_VALUE(@json,'$[0].ToTime');  
	SET @FilePath1=JSON_VALUE(@json,'$[0].FilePath1'); 
	SET @LoginId=JSON_VALUE(@json,'$[0].LoginId');    
	set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType')

	if(@Action='I')
	begin
		
			if not exists( select 1 from catalogue.carp where AppointmentID=@AppointmentID)
			begin 
					insert into catalogue.carp (PackageHeaderID,AppointmentID,AppointmentDate,FromTime,ToTime,FilePath1
					,IsActive,LastModifiedBy,LastModifiedDate) 
					select @PackageHeaderID,@AppointmentID,@AppointmentDate,@FromTime,@ToTime,@FilePath1
					,1,@LoginId,getDate()
					update Register.AppFile set FileStatus = 'S' where ObjectId = @FilePath1
					Update Catalogue.PackageHeader set CARPStatus='Available' where PackageHeaderID=@PackageHeaderID
					exec Catalogue.usp_CrossBorder_Package_Finalstatus @PackageHeaderID,@LoginId
				
					select @Msg = LanguageError from [Register].[Language_Key] 
					where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Insert'
				
					select @Msg as Msg ,cast(1 as bit) as Flag
					--select 'Carp details added successfully' as Msg ,cast(1 as bit) as Flag
			end
			else
			begin 
				select @Msg = LanguageError from [Register].[Language_Key] 
				where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Insert_Error_AlreadyExists'

				select @AppointmentID + ' - ' + @Msg as Msg ,cast(0 as bit) as Flag
				--select 'AppointmentID : '+@AppointmentID+ ' is already exists in Carp details' as Msg ,cast(0 as bit) as Flag
			end
			
			
		
	end
	else if(@Action='U')
	begin
	If not exists(select 1 from Catalogue.PackageHeader p where p.PackageHeaderID=@PackageHeaderID and p.FinalStatus='Completed')
		Begin
			SET @CARPID=JSON_VALUE(@json,'$[0].CARPID');  
			if not exists( select 1 from catalogue.carp where AppointmentID=@AppointmentID and CARPId!=@CARPID )
			begin 
			update catalogue.carp 
			set AppointmentID=@AppointmentID, 
			AppointmentDate=@AppointmentDate,
			FromTime=@FromTime,
			ToTime=@ToTime,
			FilePath1=@FilePath1,
			LastModifiedBy=@LoginId,
			LastModifiedDate=getDate()
			WHERE CARPId=@CARPID
			
			update Register.AppFile set FileStatus = 'S' where ObjectId = @FilePath1
			Update Catalogue.PackageHeader set CARPStatus='Available' where PackageHeaderID=@PackageHeaderID
			exec Catalogue.usp_CrossBorder_Package_Finalstatus @PackageHeaderID,@LoginId

			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Update'
				
			select @Msg as Msg ,cast(1 as bit) as Flag
			--select 'Carp details updated successfully' as Msg ,cast(1 as bit) as Flag
		end
		else
		begin
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Update_Error_AlreadyExists'

			select @AppointmentID + ' - ' + @Msg as Msg ,cast(0 as bit) as Flag
			--select 'AppointmentID : '+@AppointmentID+ ' is already exists in Carp details' as Msg ,cast(0 as bit) as Flag
		end
		end
	else
		begin 
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Update_Error_Completed'
				
			select @Msg as Msg ,cast(0 as bit) as Flag
			--select 'Package is already completed.So you can'' edit now.!' as Msg ,cast(0 as bit) as Flag
		end
	end
	else if(@Action='D')
	begin
		If not exists(select 1 from Catalogue.PackageHeader p where p.PackageHeaderID=@PackageHeaderID and p.FinalStatus='Completed')
		Begin 

			SET @PackageHeaderID=JSON_VALUE(@json,'$[0].PackageHeaderID');  

			update catalogue.carp 
			set 
			LastModifiedBy=@LoginId,
			LastModifiedDate=getDate()
			WHERE PackageHeaderID=@PackageHeaderID 

			delete from catalogue.carp where PackageHeaderID=@PackageHeaderID
			Update Catalogue.PackageHeader set CARPStatus='Pending' where PackageHeaderID=@PackageHeaderID

			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Delete'
				
			select @Msg as Msg ,cast(1 as bit) as Flag
			--select 'Carp details deleted successfully' as Msg ,cast(1 as bit) as Flag
		End
		Else
		begin
			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Delete_Error_Completed'
				
			select @Msg as Msg ,cast(0 as bit) as Flag
			--select 'Package is already completed.So you can'' delete now.!' as Msg ,cast(0 as bit) as Flag
		end
	end 
	 
	Commit
	End Try
	Begin Catch
		if @@TRANCOUNT > 0
		Begin
			rollback;

			insert into  Register.ErrorLog(CompanyId,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
			select  null,'Carp details',@CARPID,ERROR_MESSAGE(),GETDATE()

			select @Msg = LanguageError from [Register].[Language_Key] 
			where LanguageType = @LanguageType and LanguageKey = 'CARP_SP_CarpAction_Failed'
				
			select @Msg as Msg ,cast(0 as bit) as Flag
			--select 'Carp details not added. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag
		End
	End Catch	

END

GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Check]    Script Date: 11-04-2021 20:41:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Package_Check]  
@SellerFormID int
as
begin
	set nocount on;

	if exists(select 1 from Catalogue.PackageHeader  with (nolock)
	where SellerFormID=@SellerFormID )
	Begin
		select cast(1 as bit) as Flag
	End 
	Else
	begin
		select cast(0 as bit) as Flag
	End   
	 

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Files]    Script Date: 11-04-2021 20:41:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].[usp_Package_Files] 49,66
Create procedure [Seller].[usp_Package_Files]
@Type varchar(100),
@PackageHeaderID bigint, 
@SellerFormID int
as
begin
	set nocount on;
	
	if(@Type='Shipment')
	begin 
		select   InvoiceHeaderID UniqueNumber	,ShipmentFilePath1 FilePath 
		from Catalogue.InvoiceHeader  as sh with(nolock)				  
		where  sh.PackageHeaderID=@PackageHeaderID 
	end
	if(@Type='CheckList')
	begin 
		select   InvoiceHeaderID UniqueNumber	,CheckListFilePath1 FilePath 
		from Catalogue.InvoiceHeader  as sh with(nolock)				  
		where  sh.PackageHeaderID=@PackageHeaderID
		and CheckListID is not null	  
	end
	if(@Type='BOE')
	begin  
		select   InvoiceHeaderID UniqueNumber	,BOEFilePath1 FilePath 
		from Catalogue.InvoiceHeader  as sh with(nolock)				  
		where  sh.PackageHeaderID=@PackageHeaderID  
		and BOENumber is not null
	end

	

	set nocount off;
end  
GO

/****** Object:  StoredProcedure [Seller].[usp_Package_GenerateInvoice]    Script Date: 11-04-2021 20:41:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [Seller].[usp_Package_GenerateInvoice]
@FBAShipmentID varchar(50),
@ModeOfShipment varchar(50)=null
as
Begin
	if object_id('tempdb..#TempInvoice', 'U') is not null
	BEGIN
		drop table  #TempInvoice 
	END 
	if exists(select 1 from sys.tables where  name ='TempTable')
	begin
		drop table TempTable
	end	
	if object_id('tempdb..#Temp1', 'U') is not null
	BEGIN
		drop table  #Temp1 
	END 
	if exists(select 1 from sys.tables where  name ='tempcte')
	begin
		drop table tempcte
	end
	if exists(select 1 from sys.tables where  name ='MainCte')
	begin
		drop table MainCte
	end
					
	Declare @PerInvoiceMaxLimitInUSD int
	set @PerInvoiceMaxLimitInUSD=( select PerInvoiceMaxLimitInUSD
	from Catalogue.USDPricingMaster where active=1)
	declare @PerInvoiceMaxLimWithPermiLimitInUSD decimal(18,2)
	set @PerInvoiceMaxLimWithPermiLimitInUSD=(select PerInvoiceMaxLimitInUSD+PerInvoiceMaxPermissibleLimitinUSD from Catalogue.USDPricingMaster)
	Declare @TotalInvoiceValue decimal(18,2)
	set @TotalInvoiceValue=(select sum(unitperpriceinusd*qty) from 
	Catalogue.ConsolidatedInvoice where FBAShipmentID=@FBAShipmentID)

	if( @ModeOfShipment='Air Freight Courier')
	Begin
		if(@TotalInvoiceValue>@PerInvoiceMaxLimWithPermiLimitInUSD )
		BEGIN
			;With Cte
			as
			(
			select  CatalogueDetailID,UnitPerPriceInUSD,Qty,UnitPerPriceInUSD*Qty As TotalCataloguePrice,
			UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD as NoOfInvoice,
			CEILING(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD) as NoInvoiceGeneration,
			case  (FLOOR(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD)) when 0 then 0
			else floor( qty/( FLOOR( Qty/CEILING(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD)))) end as NoInv,
			case  (FLOOR(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD)) when 0 then 0
			else FLOOR( Qty/CEILING(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD)) end as perinvoiceQty,
			case  (FLOOR(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD)) when 0 then qty
			else qty-floor( qty/( FLOOR( Qty/CEILING(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD))))*FLOOR( Qty/CEILING(UnitPerPriceInUSD*Qty/@PerInvoiceMaxLimWithPermiLimitInUSD))
			end as leftqty
			from Catalogue.ConsolidatedInvoice where FBAShipmentID=@FBAShipmentID
			)

			select * into MainCte from cte  
			; with cte2
			as
			(
			select sum(RunningBal ) over(partition by rn) as computed,*,
			case when  sum(RunningBal ) over(partition by rn) 
			>@PerInvoiceMaxLimWithPermiLimitInUSD then 0 else 1 end
			as NewLeftQty
			from (
			select Row_number()over( order by leftqty,UnitPerPriceInUSD,CatalogueDetailID) as rn
			, leftqty*UnitPerPriceInUSD as priceleft,
			sum(leftqty*UnitPerPriceInUSD ) over(order by cte.TotalCataloguePrice, CatalogueDetailID) As RunningBal,
			1 as MergeCatalogue,
			* from MainCte CTE
			where cte.leftqty>0) t
			)
			select  *  into tempcte from cte2

			create table #Temp1   
			(
			MergeCatalogue int,						
			CatalogueDetailID bigint,
			UnitPerPriceInUSD decimal(18,2),
			Qty int,
			TotalCataloguePrice decimal(18,2),
			NoInvoiceGeneration int,
			NoInv int,
			perinvoiceqty int,
			leftqty int,
			NewLeftQty int)
			CREATE NONCLUSTERED INDEX TempTable_name
			ON #Temp1(CatalogueDetailID desc);
						
			insert into #Temp1
			(
			MergeCatalogue ,						
			CatalogueDetailID ,
			UnitPerPriceInUSD ,
			Qty ,
			TotalCataloguePrice ,
			NoInvoiceGeneration ,
			NoInv ,perinvoiceqty ,
			leftqty ,
			NewLeftQty 
			)
					
			select MergeCatalogue=1,t.CatalogueDetailID,t.UnitPerPriceInUSD,t.qty,t.TotalCataloguePrice,t.NoInvoiceGeneration
			,t.NoInv,t.perinvoiceqty,t.leftqty,
			case when  sum(RunningBal ) over(partition by CatalogueDetailID) 
			>@PerInvoiceMaxLimWithPermiLimitInUSD then 0 else 1 end
			as NewLeftQty
			from (
			select Row_number()over( order by leftqty,UnitPerPriceInUSD,CatalogueDetailID) as rn
			, leftqty*UnitPerPriceInUSD as priceleft,
			sum(leftqty* UnitPerPriceInUSD) over(order by CTE.LEFTQTY, cte.UnitPerPriceInUSD, CatalogueDetailID) As RunningBal,
			1 as MergeCatalogue,cte.CatalogueDetailID,cte.UnitPerPriceInUSD,cte.qty,cte.TotalCataloguePrice,cte.NoInvoiceGeneration
			,cte.NoInv,cte.leftqty,cte.perinvoiceqty
			from tempcte cte
			where cte.leftqty>0
			) t
			declare @ii int 
			set @ii=0

			while(@ii<1)
			begin
				insert into #Temp1
			(
				MergeCatalogue ,	CatalogueDetailID ,UnitPerPriceInUSD ,	Qty ,TotalCataloguePrice ,
				NoInvoiceGeneration ,NoInv ,perinvoiceqty ,leftqty ,NewLeftQty 
			)
			select MergeCatalogue=t.MergeCatalogue+1,t.CatalogueDetailID,t.UnitPerPriceInUSD,t.qty,t.TotalCataloguePrice,t.NoInvoiceGeneration
			,t.NoInv,t.perinvoiceqty,t.leftqty,
			case when  sum(RunningBal ) over(partition by CatalogueDetailID) 
			>@PerInvoiceMaxLimWithPermiLimitInUSD then 0 else 1 end
			as NewLeftQty
			from (
			select Row_number()over( order by leftqty,UnitPerPriceInUSD,CatalogueDetailID) as rn
			, leftqty*UnitPerPriceInUSD as priceleft,
			sum(leftqty* UnitPerPriceInUSD) over(order by CTE.LEFTQTY, cte.UnitPerPriceInUSD, CatalogueDetailID) As RunningBal,
			cte.MergeCatalogue as MergeCatalogue,cte.CatalogueDetailID,cte.UnitPerPriceInUSD,cte.qty,cte.TotalCataloguePrice,cte.NoInvoiceGeneration
			,cte.NoInv,cte.leftqty,cte.perinvoiceqty
			from tempcte cte
			where 
			NewLeftQty=0 
			) as t				
							
				select * into tempcte1   from (
			select MergeCatalogue=t.MergeCatalogue+1,t.CatalogueDetailID,t.UnitPerPriceInUSD,t.qty,t.TotalCataloguePrice,t.NoInvoiceGeneration
			,t.NoInv,t.perinvoiceqty,t.leftqty,
			case when  sum(RunningBal ) over(partition by CatalogueDetailID) 
			>@PerInvoiceMaxLimWithPermiLimitInUSD then 0 else 1 end
			as NewLeftQty
			from (
			select Row_number()over( order by leftqty,UnitPerPriceInUSD,CatalogueDetailID) as rn
			, leftqty*UnitPerPriceInUSD as priceleft,
			sum(leftqty* UnitPerPriceInUSD) over(order by CTE.LEFTQTY, cte.UnitPerPriceInUSD, CatalogueDetailID) As RunningBal,
			cte.MergeCatalogue as MergeCatalogue,cte.CatalogueDetailID,cte.UnitPerPriceInUSD,cte.qty,cte.TotalCataloguePrice,cte.NoInvoiceGeneration
			,cte.NoInv,cte.leftqty,cte.perinvoiceqty
			from tempcte cte
			where 
			NewLeftQty=0 
			) as t) tt where tt.NewLeftQty=0
					
				drop table tempcte
				select  *  into tempcte from tempcte1 
				drop table tempcte1
				set @ii= case when (select 1 from tempcte)=1 then 0 else 1 end					
			end

			;With
			cte3
			as
			( 
			select 0 as MergeCatalogue,		CatalogueDetailID ,UnitPerPriceInUSD ,Qty ,	TotalCataloguePrice ,
			NoInvoiceGeneration ,	NoInv ,perinvoiceqty ,leftqty ,
			0 as NewLeftQty  from Maincte  where leftqty=0
			union all
			select  *   from #Temp1 where NewLeftQty=1
			),
			cte4
			as
			(
				select *,0 as CatalogueRowCOUNT 	from cte3 where cte3.NoInv=0
				union all
				select * ,row_number() over( order by CatalogueDetailID) as CatalogueRowCOUNT 
				from cte3
				where cte3.NoInv>0
			)
			select * into  TempTable from cte4	
					
			CREATE NONCLUSTERED INDEX TempTable_name
			ON TempTable(NoInv,CatalogueRowCount);
					
			--Generating Invoices			*-					
					
			create table #TempInvoice 
			(
			InvoiceNumber bigint,
			CatalogueDetailID bigint,
			UnitPerPriceInUSD decimal(18,2),
			Qty int
			)	
			CREATE NONCLUSTERED INDEX TempTable_name
			ON #TempInvoice(InvoiceNumber desc);
					
			Declare @NoInv int,@CatalogueDetailID int,@PerInvoiceQty int,@MergeCatalogue int,@UnitPerPriceInUSD decimal(18,2)
			declare @LastInvoiceNumber int

			if exists (select 1 from TempTable where  NoInv!=0)
			begin
				declare @i int,
				@OuterLoop int,
				@k int
				set @k=1
				set @OuterLoop=(select count(*) from TempTable where  NoInv!=0)

				while @k<=@OuterLoop
				begin
					select @NoInv =NoInv,@CatalogueDetailID =CatalogueDetailID,@PerInvoiceQty= PerInvoiceQty,@UnitPerPriceInUSD=UnitPerPriceInUSD
					from  TempTable where  NoInv!=0 
					and CatalogueRowCount=@k
					set @i=0

					While @i<@NoInv
					Begin
						Set @LastInvoiceNumber=isnull((select top(1)  isnull(InvoiceNumber,0)  from #TempInvoice order by InvoiceNumber desc ),0)
						Insert into #TempInvoice 
						select (@LastInvoiceNumber+1) as InvoiceNumber,@CatalogueDetailID,@UnitPerPriceInUSD,@PerInvoiceQty
						set @i=@i+1
					End
					set @k=@k+1
				end
							
			End
					
						
			if exists(select 1 from TempTable where  MergeCatalogue>0 )
			begin
				declare @j1 int;
				set  @j1=1	
				set @MergeCatalogue=(select top(1) MergeCatalogue from temptable  order by MergeCatalogue desc)

				While @j1<=@MergeCatalogue
					Begin
						Set @LastInvoiceNumber=isnull((select top(1)  isnull(InvoiceNumber,0)  from #TempInvoice order by InvoiceNumber desc ),0)
						Insert into #TempInvoice 
						select (@LastInvoiceNumber+1) as InvoiceNumber,CatalogueDetailID,UnitPerPriceInUSD,leftqty as Qty
						from TempTable where MergeCatalogue=@j1
						set @j1=@j1+1
					end
			End

					 
			--select @Json =(select *  from #TempInvoice for json path)
			SELECT  case len(cast( ig.InvoiceNumber as varchar(10))) when 1  then 
		@FBAShipmentID+'0'+cast( ig.InvoiceNumber as varchar(10))else  @FBAShipmentID+cast( InvoiceNumber as varchar(10)) end
		as InvoiceNo
		,lstInvoiceDetail=(
		SELECT Distinct case len(cast( Ig.InvoiceNumber as varchar(10))) when 1  then 
		@FBAShipmentID+'0'+cast( Ig.InvoiceNumber as varchar(10))else  @FBAShipmentID+cast( Ig.InvoiceNumber as varchar(10)) end
		as InvoiceNo, cd.CatalogueDetailID,
		cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,
		igv.UnitPerPriceInUSD,igv.Qty ,igv.UnitPerPriceInUSD * igv.Qty as TotalUnitValueInUSD 
		from #TempInvoice igv
		inner join
		Catalogue.CatalogueDetail cd
		on cd.CatalogueDetailID=igv.CatalogueDetailID
		inner join Catalogue.CatalogueHeader ch	 on ch.CatalogueID=cd.CatalogueID
		where igv.InvoiceNumber=ig.InvoiceNumber 
		for json path , include_null_values 
		)
		from #TempInvoice Ig  group by Ig.InvoiceNumber for json path , include_null_values 
	END
		ELSE
		BEGIN 
		select  @FBAShipmentID+'01' as InvoiceNo  
		,lstInvoiceDetail=(
		select distinct @FBAShipmentID+'01' as InvoiceNo, c.CatalogueDetailID,
		cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,
		c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
		from 
		Catalogue.ConsolidatedInvoice as c
		inner join Catalogue.CatalogueDetail cd
		on c.cataloguedetailid=cd.CatalogueDetailID
		inner join Catalogue.CatalogueHeader ch 
		on ch.CatalogueID=cd.CatalogueID
		Where c.FBAShipmentID=@FBAShipmentID
		for json path , include_null_values )
		for json path , include_null_values 
	END
		end
	else
	begin
		select  @FBAShipmentID+'01' as InvoiceNo  
		,lstInvoiceDetail=(
		select distinct @FBAShipmentID+'01' as InvoiceNo, c.CatalogueDetailID,
		cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,
		c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
		from 
		Catalogue.ConsolidatedInvoice as c
		inner join Catalogue.CatalogueDetail cd
		on c.cataloguedetailid=cd.CatalogueDetailID
		inner join Catalogue.CatalogueHeader ch 
		on ch.CatalogueID=cd.CatalogueID
		Where c.FBAShipmentID=@FBAShipmentID
		for json path , include_null_values )
		for json path , include_null_values 
	end
end

GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Invoice_Print]    Script Date: 11-04-2021 20:41:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Package_Invoice_Print]
@PackageHeaderID bigint,
@InvoiceNumber varchar(100)
as
begin
	set nocount on;
	if(@InvoiceNumber='ConsolidatedInvoice')
	BEGIN
		select  distinct 
		(select  dbo.fnNumberToWords( sum(TotalUnitValueInUSD)) + ' Only' as AmountInwords from(
		select distinct 
		sum(c.Qty) over(partition by c.CatalogueDetailID ) as Qty,
		UnitPerPriceInUSD*sum(Qty)over(partition by c.CatalogueDetailID ) as TotalUnitValueInUSD 
		from Catalogue.InvoiceHeader i with(nolock)
		inner join Catalogue.InvoiceDetail c with(nolock)
		on i.InvoiceHeaderID=c.InvoiceHeaderID 
		where i.PackageHeaderID=@PackageHeaderID) as t) as  TotalAmuntWords, 
		(select c.CountryName from Catalogue.PackageHeader a with(nolock)
		inner join Masters.Country c with(nolock) on c.CountryID=a.CountryID
		where a.PackageHeaderID=@PackageHeaderID
		) as CountryName,  
		Ih.PackageHeaderID,
		(select top(1) a.FBAShipmentID from Catalogue.PackageHeader a with(nolock) where PackageHeaderID=ih.PackageHeaderID)as InvoiceNo,
		(select top(1) a.STNDate from Catalogue.PackageHeader a with(nolock) where PackageHeaderID=ih.PackageHeaderID)InvoiceDate,
		Ih.BuyerOrderNo,Ih.BuyerOrderDate,
		Ih.ConsigneeID ,Ih.ConsignorID
		,(select top(1)v.VendorName from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as ConsignorName,
		(select top(1)v.Address1 from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as ConsignorAddress,
		--(select  top(1)c.CompanyName from Register.Company c where c.CompanyID=ih.ConsigneeID)  as ConsigneeName,
		(select  top(1) c.CompanyName+' '+ s.Address1+' '+s.City+' '+d.State+' '+s.Pincode
		from Register.Company c with(nolock)
		inner join catalogue.ppob s with(nolock) on s.CompanyID=c.CompanyID
		inner join Masters.State d with(nolock)
		on d.StateID=s.StateID 
		where c.CompanyID=ih.ConsigneeID)
		as ConsigneeAddress,
		(select  top(1)p.GSTNumber from Register.Company c with(nolock) inner join catalogue.ppob p with(nolock) on p.CompanyID=c.CompanyID
		where c.CompanyID=ih.ConsigneeID)
		as GSTIN,'AAFCV5265N' as IEC,
		(select top(1) V.MobileNumber from Catalogue.SellerRegistration v with(nolock)					
		where v.SellerFormID=ih.SellerFormID) as MobileNumber,
		(select  top(1)p.Pincode from Register.Company c with(nolock)
		inner join catalogue.ppob p with(nolock) on p.CompanyID=c.CompanyID 
		where c.CompanyID=ih.ConsigneeID)
		as Pincode,
		--ih.ShippingRemarks,
		-- (select ShipFrom from Catalogue.PackageHeader where PackageHeaderID=ih.PackageHeaderID
		--)
		'' as ShipFrom,
		--(select ShipTO from Catalogue.PackageHeader where PackageHeaderID=ih.PackageHeaderID
		--)
		'' as ShipTO,
		--(select top(1)v.BeneficiaryName from masters.vendor v where v.VendorID=ih.ConsignorID) as BeneficiaryName,
						
		(select top(1)v.BankName from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as BeneficiaryBankName,
		(select a.BeneficiaryName+' '+ a.Address1+' '+a.City+' '+b.State from Masters.Vendor a with(nolock)
		inner join Masters.State b with(nolock)
		on a.StateID=b.StateID
		where VendorID=ih.ConsignorID) as BeneficiaryAddress,
		(select top(1)v.VendorName from  masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as AccountName,
		(select top(1)v.AccountNumber from  masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as AccountNumber,

		(select top(1)v.MarketPlaceSellerID from Catalogue.SellerRegistration v with(nolock) where v.SellerFormID=ih.SellerFormID) as MarketPlaceSellerID,
		(select top(1)v.AccountNumber from register.JenniferMobileMaster v with(nolock) where v.SellerFormID=ih.SellerFormID) as SellerAccountNumber,
		(select top(1) IFSCCode from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as SWIFTCode
		,Ih.Aircraft,Ih.SailingOnOrAbout,Ih.ShippingRemarks,Ih.TermsOfDelivery,ih.[from] ,
						
		--  Invoice detail for by header id 
		lstInvoiceDetail=(
			select distinct row_number() over(order by c.CatalogueDetailID) as SLNo,c.CatalogueDetailID,
			cd.ProductName,cd.MerchantSKU,cd.CTH_HSN as HSNCode,c.UnitPerPriceInUSD,
			sum(c.Qty) as Qty,UnitPerPriceInUSD*sum(Qty) as TotalUnitValueInUSD 
			from Catalogue.InvoiceHeader i with(nolock)
			inner join Catalogue.InvoiceDetail c with(nolock)	on i.InvoiceHeaderID=c.InvoiceHeaderID
			inner join Catalogue.CatalogueDetail cd	with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
			inner join Catalogue.CatalogueHeader ch	with(nolock) on ch.CatalogueID=cd.CatalogueID	
			where i.PackageHeaderID=@PackageHeaderID
			group by c.CatalogueDetailID,cd.ProductName,cd.MerchantSKU,CTH_HSN,UnitPerPriceInUSD,i.PackageHeaderID
			for json path , include_null_values
		)				
		from Catalogue.InvoiceHeader Ih  
		where Ih.IsActive=1 and Ih.PackageHeaderID=@PackageHeaderID 
						
		for json path , include_null_values,without_array_wrapper
	END
	else
	begin
		select  distinct
		(select  dbo.fnNumberToWords( sum(TotalUnitValueInUSD)) + ' Only' as AmountInwords from(
		select distinct						
		sum(c.Qty) over(partition by c.CatalogueDetailID ) as Qty,
		UnitPerPriceInUSD*sum(Qty)over(partition by c.CatalogueDetailID ) as TotalUnitValueInUSD 
		from Catalogue.InvoiceHeader i with(nolock)
		inner join 	Catalogue.InvoiceDetail c with(nolock)	on i.InvoiceHeaderID=c.InvoiceHeaderID 
		where i.PackageHeaderID=@PackageHeaderID and i.InvoiceNo=@InvoiceNumber) as t) as  TotalAmuntWords,
		(select c.CountryName from Catalogue.PackageHeader a with(nolock)
		inner join Masters.Country c with(nolock) on c.CountryID=a.CountryID
		where a.PackageHeaderID=@PackageHeaderID
		) as CountryName,  
		Ih.PackageHeaderID,ih.InvoiceHeaderID,Ih.InvoiceNo,Ih.InvoiceDate,
		Ih.BuyerOrderNo,Ih.BuyerOrderDate,
		Ih.ConsigneeID ,Ih.ConsignorID
		,(select top(1)v.VendorName from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as ConsignorName,
		(select top(1)v.Address1 from masters.vendor v where v.VendorID=ih.ConsignorID) as ConsignorAddress,
		--(select  top(1)c.CompanyName from Register.Company c where c.CompanyID=ih.ConsigneeID)  as ConsigneeName,
		(select  top(1) c.CompanyName+' '+ s.Address1+' '+s.City+' '+d.State+' '+s.Pincode
		from Register.Company c with(nolock)
		inner join catalogue.ppob s with(nolock) on s.CompanyID=c.CompanyID
		inner join Masters.State d with(nolock)
		on d.StateID=s.StateID
		where c.CompanyID=ih.ConsigneeID)
		as ConsigneeAddress,
		(select  top(1)p.GSTNumber from Register.Company c
		inner join catalogue.ppob p with(nolock)on p.CompanyID=c.CompanyID
		where c.CompanyID=ih.ConsigneeID)
		as GSTIN,'AAFCV5265N' as IEC,
		(select top(1) V.MobileNumber from Catalogue.SellerRegistration v with(nolock)					
		where v.SellerFormID=ih.SellerFormID) as MobileNumber,
		(select  top(1)p.Pincode from Register.Company c with(nolock)
		inner join catalogue.ppob p with(nolock) on p.CompanyID=c.CompanyID
		where c.CompanyID=ih.ConsigneeID)
			as Pincode,
			--ih.ShippingRemarks,
		-- (select ShipFrom from Catalogue.PackageHeader where PackageHeaderID=ih.PackageHeaderID
		--)
		''as ShipFrom,
		--(select ShipTO from Catalogue.PackageHeader where PackageHeaderID=ih.PackageHeaderID
		--)as
		'' as ShipTO,
		--(select top(1)v.BeneficiaryName from masters.vendor v where v.VendorID=ih.ConsignorID) as BeneficiaryName,
						
		(select top(1)v.BankName from masters.vendor v where v.VendorID=ih.ConsignorID) as BeneficiaryBankName,
		(select a.BeneficiaryName+' '+ a.Address1+' '+a.City+' '+b.State from Masters.Vendor a
		inner join Masters.State b with(nolock) on a.StateID=b.StateID
		where VendorID=ih.ConsignorID) as BeneficiaryAddress,
		(select top(1)v.VendorName from  masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as AccountName,
		(select top(1)v.AccountNumber from  masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as AccountNumber,

		(select top(1)v.MarketPlaceSellerID from Catalogue.SellerRegistration v with(nolock) where v.SellerFormID=ih.SellerFormID) as MarketPlaceSellerID,
		(select top(1)v.AccountNumber from register.JenniferMobileMaster v with(nolock) where v.SellerFormID=ih.SellerFormID) as SellerAccountNumber,
		(select top(1) IFSCCode from masters.vendor v with(nolock) where v.VendorID=ih.ConsignorID) as SWIFTCode
		,Ih.Aircraft,Ih.SailingOnOrAbout,Ih.ShippingRemarks,Ih.TermsOfDelivery,ih.[from] ,
						
		--  Invoice detail for by header id 
		lstInvoiceDetail=(
			select distinct row_number() over(order by c.CatalogueDetailID) as SLNo,c.CatalogueDetailID,
			cd.ProductName,cd.MerchantSKU,cd.CTH_HSN as HSNCode,c.UnitPerPriceInUSD,
			sum(c.Qty) as Qty,UnitPerPriceInUSD*sum(Qty) as TotalUnitValueInUSD 
			from Catalogue.InvoiceDetail c with(nolock)
			inner join Catalogue.CatalogueDetail cd	 with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
			inner join Catalogue.CatalogueHeader ch	with(nolock) on ch.CatalogueID=cd.CatalogueID	
			where c.InvoiceHeaderID=Ih.InvoiceHeaderID 
			group by c.CatalogueDetailID,cd.ProductName,cd.MerchantSKU,CTH_HSN,UnitPerPriceInUSD
			for json path , include_null_values
		)				
		from Catalogue.InvoiceHeader Ih with(nolock) 
		where Ih.IsActive=1 and Ih.PackageHeaderID=@PackageHeaderID   and ih.InvoiceNo=@InvoiceNumber 
						
		for json path , include_null_values,without_array_wrapper
						
	
	end

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Search]    Script Date: 11-04-2021 20:41:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Exec Seller.usp_Package_Search  @SearchBy='Pending',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Package_Search] 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@SellerFormID int
as
begin
	set nocount on;

	if(@SearchBy='All')
	begin
		select distinct a.PackageHeaderID ,a.PackageDate,a.FBAShipmentID, 
		(select count(PackageHeaderID) from Catalogue.PackageHistory ih  with (nolock) where ih.PackageHeaderID=a.PackageHeaderID) as NoOfIssue
		,a.CARPStatus  
		,a.STNInvoiceStatus
		,Case when a.FinalStatus ='Completed' then 'Completed'
		when a.FinalStatus='Pending' and STNInvoiceStatus='Approved'  then 'Pending'
		When a.STNInvoiceStatus IN ('Hold','Rejected','Resend')  then 'Requested resend'
		When a.STNInvoiceStatus IN ('Pending')  then 'Under Review'
		Else a.FinalStatus End  
		FinalStatus  
		from [Catalogue].PackageHeader as a with (nolock)
		where a.SellerFormID=@SellerFormID  
		and (a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%') 
		order by a.PackageHeaderID desc
		for json path
	end
	else if(@SearchBy='Draft')
	begin
		select distinct a.PackageHeaderID ,a.PackageDate,a.FBAShipmentID, 
		(select count(PackageHeaderID) from Catalogue.PackageHistory_temp ih  with (nolock) where ih.PackageHeaderID=a.PackageHeaderID) as NoOfIssue
		,a.CARPStatus  
		,a.STNInvoiceStatus
		,'Draft' FinalStatus  
		from Catalogue.PackageHeader_temp as a with (nolock)
		where a.SellerFormID=@SellerFormID  
		and (a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%') 
		order by a.PackageHeaderID desc
		for json path
	end
	else
	begin
		select distinct a.PackageHeaderID ,a.PackageDate,a.FBAShipmentID, 
		(select count(PackageHeaderID) from Catalogue.PackageHistory ih  with (nolock) where ih.PackageHeaderID=a.PackageHeaderID) as NoOfIssue
		,a.CARPStatus  
		,a.STNInvoiceStatus
		,Case when a.FinalStatus ='Completed' then 'Completed'
		when a.FinalStatus='Pending' and STNInvoiceStatus='Approved'  then 'Pending'
		When a.STNInvoiceStatus IN ('Hold','Rejected','Resend')  then 'Requested resend'
		When a.STNInvoiceStatus IN ('Pending')  then 'Under Review'
		Else a.FinalStatus End  
		FinalStatus  
		from [Catalogue].PackageHeader as a with (nolock)
		where a.SellerFormID=@SellerFormID   
		and (@SearchBy='Pending' and FinalStatus='Pending' and STNInvoiceStatus='Approved'  and a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%'  
		or (@SearchBy='Completed' and FinalStatus='Completed'  and a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%') 
		or (@SearchBy='Requested resend' and a.STNInvoiceStatus IN ('Hold','Rejected','Resend')  and a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%')
		or (@SearchBy='Under Review' and a.STNInvoiceStatus IN ('Pending')  and a.FBAShipmentID LIKE '%' + isnull(@Search,'') + '%')   
		)  
		order by a.PackageHeaderID desc
		for json path
	end
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_SearchById]    Script Date: 11-04-2021 20:41:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- [Seller].[usp_Package_SearchById] 'AT',217,142
CREATE procedure [Seller].[usp_Package_SearchById]
@SearchBy varchar(10)='', -- AT - Actual table | DT - Draft table 
@PackageHeaderID bigint,
@SellerFormID int
as
begin
	set nocount on;
	
	
	if(@SearchBy='AT')
	begin

		select  distinct a.CountryID,a.LogisticPartnerID, a.PackageHeaderID,a.PackageNumber,a.PackageDate,a.FBAShipmentID,a.ModeOfShipment,
		(select top(1) VendorName from Masters.Vendor v with(nolock) inner join Catalogue.InvoiceHeader ih with(nolock) on v.VendorID=ih.ConsignorID
		where ih.PackageHeaderID=a.PackageHeaderID and ih.PackageHeaderID=@PackageHeaderID) as EORName,
		(select top(1) LogisticPartnerName from catalogue.LogisticPartner lo with(nolock)
		where lo.LogisticPartnerID=a.LogisticPartnerID and a.PackageHeaderID=@PackageHeaderID) as LogisticPartner,
		(select top(1) lo.CountryName from  Masters.Country lo with(nolock)
		where lo.CountryID=a.CountryID and a.PackageHeaderID=@PackageHeaderID) as CountryName,
		case  (select top(1) 1 from Catalogue.InvoiceHeader ih  where ih.PackageHeaderID=a.PackageHeaderID and ih.DocketNumber is null 
		and a.PackageHeaderID=@PackageHeaderID) 
		when 1 then 0 else 1 end as IsShipmentAvialable,
		case  (select 1 from Catalogue.POD ih  where ih.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID ) 
		when 1 then 1 else 0 end as ISPODAvailable,
		(SELECT s.MarketPlaceSellerID FROM Catalogue.SellerRegistration s with(nolock)
		where s.SellerFormID=a.SellerFormID and a.PackageHeaderID=@PackageHeaderID) as MarketPlaceSellerID,
		(SELECT s.IndianGSTNumber FROM Register.JenniferMobileMaster s with(nolock)
		where s.SellerFormID=a.SellerFormID and a.PackageHeaderID=@PackageHeaderID) as IndianGSTNumber,
		a.STNNumber,
		a.STNDate,
		(SELECT c.CompanyName FROM  Catalogue.PPOB as s with(nolock) 
		inner join Register.Company c 	with(nolock) on c.CompanyID=s.CompanyID 
		where s.PPOBID=a.ShipFrom and a.PackageHeaderID=@PackageHeaderID) as ShipFromName,
		(SELECT s.Address1 FROM  Catalogue.PPOB as s with(nolock)
		where s.PPOBID=a.ShipFrom and a.PackageHeaderID=@PackageHeaderID) as ShipFromAddress,
		(SELECT s.LocationName as ShipToName FROM  Masters.Location as s with(nolock)
		where s.LocationID=a.ShipTO and a.PackageHeaderID=@PackageHeaderID) as ShipToName,
		(SELECT s.Address1 as ShipToName FROM  Masters.Location as s with(nolock)
		where s.LocationID=a.ShipTO and a.PackageHeaderID=@PackageHeaderID) as ShipToAddress,
		(SELECT s.AppointmentID FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentID,
		(SELECT s.AppointmentDate FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentDate,
		(SELECT s.FromTime FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as FromTime,
		(SELECT s.ToTime FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as ToTime,
		(SELECT s.FilePath1 FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as CARPFilePath1,
		(SELECT s.FilePath1 FROM  Catalogue.POD as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as PODFilePath1,
		STUFF(
		(select ','+ ch.CatalogueNumber FROM 
		Catalogue.PackageDetail pd with(nolock)
		inner join Catalogue.CatalogueDetail as s  with(nolock) on pd.CatalogueDetailID=s.CatalogueDetailID
		inner join Catalogue.CatalogueHeader ch with(nolock) on ch.CatalogueID=s.CatalogueID 
		where pd.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID   FOR XML PATH(''), TYPE).value('.','VARCHAR(max)'), 1, 1, '')
		as ReferenceCatalogues,		
		(select count(PackageHeaderID) from Catalogue.InvoiceHeader ih with(nolock) where ih.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID and ih.IsActive=1) as NoOfInvoice
		,STNInvoiceStatus
		,a.BOEStatus
		,a.CARPStatus
		,a.CheckListStatus
		,a.PODStatus 
		,case when (select COUNT(PackageHeaderID) from Catalogue.InvoiceHeader as ci 
		where isnull(DocketNumber,'')!='' and ci.PackageHeaderID=A.PackageHeaderID)>0 then 'Available' else 'NA' end   ShipmentStatus
		,a.FinalStatus 
		,a.ShipFrom
		,a.ShipTo		
		,u.firstName +isnull(u.lastname,'') as CreatedByName 

		--  package detail for by header id
		,lstPackageDetail = (
			select  a.PackageHeaderID,pd.CatalogueDetailID,c.ProductName,c.ASIN,c.MerchantSKU,pd.FNSKU,
			d.CatalogueNumber,c.HSNCode,
			pd.MRPInINR,pd.Qty,pd.BoxQty,pd.WeightQty 
			from  Catalogue.PackageDetail pd with(nolock)
			inner join Catalogue.CatalogueDetail c with(nolock) on c.CatalogueDetailID=pd.CatalogueDetailID
			inner join Catalogue.CatalogueHeader d	with(nolock) on d.CatalogueID=c.CatalogueID				 
			where pd.PackageHeaderID=a.PackageHeaderID
			for json path , include_null_values
		),
		--  Invoice Header for by header id
		lstInvoiceHeader=(
			select  distinct Ih.PackageHeaderID,ih.InvoiceHeaderID,Ih.InvoiceNo,Ih.InvoiceDate,Ih.BuyerOrderNo,Ih.BuyerOrderDate,
			Ih.ConsigneeID ,Ih.ConsignorID
			,(select top(1)v.VendorName from masters.vendor v where v.VendorID=ih.ConsignorID) as ConsignorName,
			(select top(1)v.Address1 from masters.vendor v where v.VendorID=ih.ConsignorID) as ConsignorAddress,
			(select  top(1)c.CompanyName from Register.Company c where c.CompanyID=ih.ConsigneeID)  as ConsigneeName,
			(select  top(1)p.Address1 from Register.Company c inner join catalogue.ppob p on p.CompanyID=c.CompanyID
			where c.CompanyID=ih.ConsigneeID)
			as ConsigneeAddress
			,Ih.Aircraft,Ih.[From] as InvoiceFrom,Ih.SailingOnOrAbout,Ih.ShippingRemarks,Ih.TermsOfDelivery,
			--  Invoice detail for by header id 
			lstInvoiceDetail=(
				select distinct ih.InvoiceNo, c.CatalogueDetailID,
				cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,pd.FNSKU,
				c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
				from Catalogue.InvoiceDetail c
				inner join Catalogue.CatalogueDetail cd	 with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
				inner join Catalogue.CatalogueHeader ch	 with(nolock) on ch.CatalogueID=cd.CatalogueID	
				inner join Catalogue.PackageDetail pd with(nolock) on pd.PackageHeaderID=a.PackageHeaderID
				and pd.CatalogueDetailID=c.CatalogueDetailID
				where c.InvoiceHeaderID=Ih.InvoiceHeaderID  
				for json path , include_null_values
				)				
			from Catalogue.InvoiceHeader Ih  
			where Ih.IsActive=1 and Ih.PackageHeaderID=a.PackageHeaderID  
			for json path , include_null_values
		),
		--consolidated list 
		lstConsolidatedInvoice=
			(select c.CatalogueDetailID,
			cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,pd.FNSKU,
			c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
			from Catalogue.ConsolidatedInvoice c with(nolock)
			inner join Catalogue.CatalogueDetail cd	 with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
			inner join Catalogue.CatalogueHeader ch	 with(nolock) on ch.CatalogueID=cd.CatalogueID	
			inner join Catalogue.PackageDetail pd with(nolock) on pd.PackageHeaderID=a.PackageHeaderID
			and pd.CatalogueDetailID=c.CatalogueDetailID
			where c.FBAShipmentID=a.FBAShipmentID  
			for json path , include_null_values) 
		--Package History
		,lstPackageHistory=(
			select isnull ( (
			select a.PackageNumber,ca.PackageHeaderStatus,ca.PackageHeaderRemarks
			,u.firstName +isnull(u.lastname,'') as UpdatedByName ,
			ca.CreatedDate  as UpdatedDate			
			,UserType	  
			from Catalogue.PackageHistory  as ca with(nolock)
			inner join Register.users u	with(nolock) on u.userid=ca.CreatedBy 
			where  ca.PackageHeaderID=a.PackageHeaderID
			order by ca.CreatedDate desc 
			for json path),'[]') 
		)
		from Catalogue.PackageHeader as a with(nolock)
		inner join Register.users u	with(nolock) on u.userid=a.LastModifiedBy  
		where a.PackageHeaderID=@PackageHeaderID and a.SellerFormID=@SellerFormID
		for json path,without_array_wrapper
	end
	else if (@SearchBy='DT')
	begin
		select  distinct a.CountryID,a.LogisticPartnerID, a.PackageHeaderID,a.PackageNumber,a.PackageDate,a.FBAShipmentID,a.ModeOfShipment,
		(select top(1) VendorName from Masters.Vendor v with(nolock) inner join Catalogue.InvoiceHeader ih with(nolock) on v.VendorID=ih.ConsignorID
		where ih.PackageHeaderID=a.PackageHeaderID and ih.PackageHeaderID=@PackageHeaderID) as EORName,
		(select top(1) LogisticPartnerName from catalogue.LogisticPartner lo with(nolock)
		where lo.LogisticPartnerID=a.LogisticPartnerID and a.PackageHeaderID=@PackageHeaderID) as LogisticPartner,
		(select top(1) lo.CountryName from  Masters.Country lo with(nolock)
		where lo.CountryID=a.CountryID and a.PackageHeaderID=@PackageHeaderID) as CountryName,
		case  (select top(1) 1 from Catalogue.InvoiceHeader ih  where ih.PackageHeaderID=a.PackageHeaderID and ih.DocketNumber is null 
		and a.PackageHeaderID=@PackageHeaderID) 
		when 1 then 0 else 1 end as IsShipmentAvialable,
		case  (select 1 from Catalogue.POD ih  where ih.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID ) 
		when 1 then 1 else 0 end as ISPODAvailable,
		(SELECT s.MarketPlaceSellerID FROM Catalogue.SellerRegistration s with(nolock)
		where s.SellerFormID=a.SellerFormID and a.PackageHeaderID=@PackageHeaderID) as MarketPlaceSellerID,
		(SELECT s.IndianGSTNumber FROM Register.JenniferMobileMaster s with(nolock)
		where s.SellerFormID=a.SellerFormID and a.PackageHeaderID=@PackageHeaderID) as IndianGSTNumber,
		a.STNNumber,
		a.STNDate,
		(SELECT c.CompanyName FROM  Catalogue.PPOB as s with(nolock) 
		inner join Register.Company c 	with(nolock) on c.CompanyID=s.CompanyID 
		where s.PPOBID=a.ShipFrom and a.PackageHeaderID=@PackageHeaderID) as ShipFromName,
		(SELECT s.Address1 FROM  Catalogue.PPOB as s with(nolock)
		where s.PPOBID=a.ShipFrom and a.PackageHeaderID=@PackageHeaderID) as ShipFromAddress,
		(SELECT s.LocationName as ShipToName FROM  Masters.Location as s with(nolock)
		where s.LocationID=a.ShipTO and a.PackageHeaderID=@PackageHeaderID) as ShipToName,
		(SELECT s.Address1 as ShipToName FROM  Masters.Location as s with(nolock)
		where s.LocationID=a.ShipTO and a.PackageHeaderID=@PackageHeaderID) as ShipToAddress,
		(SELECT s.AppointmentID FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentID,
		(SELECT s.AppointmentDate FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentDate,
		(SELECT s.FromTime FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as FromTime,
		(SELECT s.ToTime FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as ToTime,
		(SELECT s.FilePath1 FROM  Catalogue.CARP as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as CARPFilePath1,
		(SELECT s.FilePath1 FROM  Catalogue.POD as s with(nolock)
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as PODFilePath1,
		STUFF(
		(select ','+ ch.CatalogueNumber FROM 
		catalogue.PackageDetail_temp pd with(nolock)
		inner join Catalogue.CatalogueDetail as s  with(nolock) on pd.CatalogueDetailID=s.CatalogueDetailID
		inner join Catalogue.CatalogueHeader ch with(nolock) on ch.CatalogueID=s.CatalogueID 
		where pd.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID   FOR XML PATH(''), TYPE).value('.','VARCHAR(max)'), 1, 1, '')
		as ReferenceCatalogues,		
		(select count(PackageHeaderID) from Catalogue.InvoiceHeader ih with(nolock) where ih.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID and ih.IsActive=1) as NoOfInvoice
		,STNInvoiceStatus
		,a.BOEStatus
		,a.CARPStatus
		,a.CheckListStatus
		,a.PODStatus 
		,a.FinalStatus 
		,a.ShipFrom
		,a.ShipTo		
		,u.firstName +isnull(u.lastname,'') as CreatedByName 

		--  package detail for by header id
		,lstPackageDetail = (
			select  a.PackageHeaderID,pd.CatalogueDetailID,c.ProductName,c.ASIN,c.MerchantSKU,pd.FNSKU,
			d.CatalogueNumber,c.HSNCode,
			pd.MRPInINR,pd.Qty,pd.BoxQty,pd.WeightQty 
			from  catalogue.PackageDetail_temp pd with(nolock)
			inner join Catalogue.CatalogueDetail c with(nolock) on c.CatalogueDetailID=pd.CatalogueDetailID
			inner join Catalogue.CatalogueHeader d	with(nolock) on d.CatalogueID=c.CatalogueID				 
			where pd.PackageHeaderID=a.PackageHeaderID
			for json path , include_null_values
		),
		--  Invoice Header for by header id
		lstInvoiceHeader=(
			select isnull ( (
			select  distinct Ih.PackageHeaderID,ih.InvoiceHeaderID,Ih.InvoiceNo,Ih.InvoiceDate,Ih.BuyerOrderNo,Ih.BuyerOrderDate,
			Ih.ConsigneeID ,Ih.ConsignorID
			,(select top(1)v.VendorName from masters.vendor v where v.VendorID=ih.ConsignorID) as ConsignorName,
			(select top(1)v.Address1 from masters.vendor v where v.VendorID=ih.ConsignorID) as ConsignorAddress,
			(select  top(1)c.CompanyName from Register.Company c where c.CompanyID=ih.ConsigneeID)  as ConsigneeName,
			(select  top(1)p.Address1 from Register.Company c inner join catalogue.ppob p on p.CompanyID=c.CompanyID
			where c.CompanyID=ih.ConsigneeID)
			as ConsigneeAddress
			,Ih.Aircraft,Ih.[From] as InvoiceFrom,Ih.SailingOnOrAbout,Ih.ShippingRemarks,Ih.TermsOfDelivery,
			--  Invoice detail for by header id 
			lstInvoiceDetail=(
				select distinct ih.InvoiceNo, c.CatalogueDetailID,
				cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,pd.FNSKU,
				c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
				from Catalogue.InvoiceDetail c
				inner join Catalogue.CatalogueDetail cd	 with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
				inner join Catalogue.CatalogueHeader ch	 with(nolock) on ch.CatalogueID=cd.CatalogueID	
				inner join catalogue.PackageDetail_temp pd with(nolock) on pd.PackageHeaderID=a.PackageHeaderID
				and pd.CatalogueDetailID=c.CatalogueDetailID
				where c.InvoiceHeaderID=Ih.InvoiceHeaderID  
				for json path , include_null_values
				)				
			from Catalogue.InvoiceHeader Ih  
			where Ih.IsActive=1 and Ih.PackageHeaderID=a.PackageHeaderID  
			for json path , include_null_values
			),'[]') 
		) 
		--consolidated list 
		,lstConsolidatedInvoice=(
			select isnull ( (
				select c.CatalogueDetailID,
				cd.ASIN,cd.ProductName,cd.MerchantSKU,ch.CatalogueNumber,cd.HSNCode,pd.FNSKU,
				c.UnitPerPriceInUSD,c.Qty ,c.UnitPerPriceInUSD * c.Qty TotalUnitValueInUSD 
				from Catalogue.ConsolidatedInvoice c with(nolock)
				inner join Catalogue.CatalogueDetail cd	 with(nolock) on cd.CatalogueDetailID=C.CatalogueDetailID
				inner join Catalogue.CatalogueHeader ch	 with(nolock) on ch.CatalogueID=cd.CatalogueID	
				inner join catalogue.PackageDetail_temp pd with(nolock) on pd.PackageHeaderID=a.PackageHeaderID
				and pd.CatalogueDetailID=c.CatalogueDetailID
				where c.FBAShipmentID=a.FBAShipmentID  
				for json path , include_null_values
				),'[]') 
			)
		--Package History
		,lstPackageHistory=(
			select isnull ( (
			select a.PackageNumber,ca.PackageHeaderStatus,ca.PackageHeaderRemarks
			,u.firstName +isnull(u.lastname,'') as UpdatedByName ,
			ca.CreatedDate  as UpdatedDate			
			,UserType	  
			from catalogue.PackageHistory_temp  as ca with(nolock)
			inner join Register.users u	with(nolock) on u.userid=ca.CreatedBy 
			where  ca.PackageHeaderID=a.PackageHeaderID
			order by ca.CreatedDate desc 
			for json path
			),'[]') 
		)
		from catalogue.PackageHeader_temp as a with(nolock)
		inner join Register.users u	with(nolock) on u.userid=a.LastModifiedBy  
		where a.PackageHeaderID=@PackageHeaderID and a.SellerFormID=@SellerFormID
		for json path,without_array_wrapper
	end

set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_SKU_Print]    Script Date: 11-04-2021 20:41:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Package_SKU_Print]
@PackageHeaderID bigint,
@SellerFormID int
as
begin
	set nocount on;
	
	
		select  distinct  
		(SELECT c.CompanyName+' '+ s.Address1+' '+s.City+' '+d.State+' '+s.Pincode FROM  Catalogue.PPOB as s 
		inner join Register.Company c  with (nolock) on c.CompanyID=s.CompanyID
		inner join Masters.State d 	 with (nolock) on d.StateID=s.StateID
		where s.PPOBID=a.ShipFrom and a.PackageHeaderID=@PackageHeaderID) as ShipFromAddress, 
		(SELECT s.LocationName+' '+ s.Address1 +' '+s.City+' '+d.State+' '+s.PostalCode 
		FROM  Masters.Location as s  with (nolock) 
		inner join Masters.State d  with (nolock) on d.StateID=s.StateID 
		where s.LocationID=a.ShipTO and a.PackageHeaderID=@PackageHeaderID
		) as ShipToAddress,
		(SELECT s.AppointmentID FROM  Catalogue.CARP as s  with (nolock) 
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentID,
		(SELECT s.AppointmentDate FROM  Catalogue.CARP as s 
		where s.PackageHeaderID=a.PackageHeaderID and a.PackageHeaderID=@PackageHeaderID) as AppointmentDate,
		(
		SELECT top(1) c.IndianGSTNumber  FROM Catalogue.SellerRegistration s   with (nolock) 
		inner join  Register.JenniferMobileMaster as c  with (nolock)  on s.SellerFormID=c.SellerFormID  
		where s.SellerFormID=a.SellerFormID) as GSTIN,
		a.FBAShipmentID 
		--  package detail for by header id
		,lstPackageDetail = (
						select row_number() over(order by pd.CatalogueDetailID) as SNo ,c.ProductName,c.ASIN,c.MerchantSKU,pd.FNSKU
						,c.HSNCode,
						pd.MRPInINR,pd.Qty,pd.BoxQty,pd.WeightQty 
						from  Catalogue.PackageDetail pd  with (nolock) 
						inner join Catalogue.CatalogueDetail c  with (nolock) on c.CatalogueDetailID=pd.CatalogueDetailID
						inner join Catalogue.CatalogueHeader d	 with (nolock) on d.CatalogueID=c.CatalogueID				 
						where pd.PackageHeaderID=a.PackageHeaderID
						for json path , include_null_values
							)
		from Catalogue.PackageHeader as a
		inner join Register.users u	 with (nolock) on u.userid=a.LastModifiedBy  
		where a.PackageHeaderID=@PackageHeaderID and a.SellerFormID=@SellerFormID
		for json path,without_array_wrapper,include_null_values
	
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Package_Status]    Script Date: 11-04-2021 20:41:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- exec [Seller].[usp_Package_Status] 81 
CREATE procedure  [Seller].[usp_Package_Status]
@SellerFormID int
as
begin 

	set nocount on;

	select FinalStatus,StatusCount,LastModifiedDate from (
	select 'Completed' FinalStatus,	count(FinalStatus) StatusCount,
	 max(LastModifiedDate)  LastModifiedDate 
	from Catalogue.PackageHeader with (nolock)	where SellerFormID=@SellerFormID   and FinalStatus='Completed'
	union all
	select 'Pending' FinalStatus,	count(FinalStatus) StatusCount,
	convert(date, max(LastModifiedDate),103) as LastModifiedDate 
	from Catalogue.PackageHeader with (nolock)	where SellerFormID=@SellerFormID   and FinalStatus='Pending'
	and STNInvoiceStatus='Approved' 
	union all
	select 'Under Review' FinalStatus,	count(FinalStatus) StatusCount,
	convert(date, max(LastModifiedDate),103) as LastModifiedDate 
	from Catalogue.PackageHeader with (nolock)	where SellerFormID=@SellerFormID   
	AND STNInvoiceStatus='Pending' 
	union all
	select 'Requested resend' FinalStatus,	count(FinalStatus) StatusCount,
	convert(date, max(LastModifiedDate),103) as LastModifiedDate 
	from Catalogue.PackageHeader with (nolock)	where SellerFormID=@SellerFormID 
	AND STNInvoiceStatus IN ('Hold','Rejected','Resend')
	union all
	select 'Draft' FinalStatus,	count(PackageHeaderID) StatusCount,
	convert(date, max(LastModifiedDate),103) as LastModifiedDate 
	from Catalogue.PackageHeader_temp with (nolock)	where SellerFormID=@SellerFormID
	)  as a for json path 

	set nocount off;

end

GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_AgreeStatus]    Script Date: 11-04-2021 20:41:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Seller.usp_SellerStatement_StatusUpdate '' 
CREATE  proc [Seller].[usp_Payment_AgreeStatus]
@json varchar(max)
as 
begin
Begin Try
	Begin Tran   
	
	set @json=concat('[' ,@json , ']')  

	declare @StatementNumber varchar(100)
	declare @Status varchar(30)
	declare @CompanyDetailID  CompanyDetailID   
	declare @LoginId  UserId 
	declare @Msg nvarchar(1000)
	declare @LanguageType varchar(10) = 'en'

	SET @StatementNumber=JSON_VALUE(@json,'$[0].StatementNumber');  
	SET @Status=JSON_VALUE(@json,'$[0].Status');   
	SET @CompanyDetailID=JSON_VALUE(@json,'$[0].CompanyDetailID');	
	SET @LoginId=JSON_VALUE(@json,'$[0].LoginId');	
	set @LanguageType = JSON_VALUE(@json, '$[0].LanguageType')

	Update Payment.Statements set Statement_Approved_Status=@Status, Approved_By=@LoginId, Approved_On = getdate() 
	where CompanyDetailID=@CompanyDetailID and StatementNumber=@StatementNumber

	update Register.SupportQuery set SupportStatus='Closed', LastModifiedDate = GETDATE() 
	where ReferenceNumber=@StatementNumber --and CompanyDetailID = @CompanyDetailID 

	select @Msg = LanguageError from [Register].[Language_Key] 
	where LanguageType = @LanguageType and LanguageKey = 'STATEMENTVIEW_SP_SellerStatement_StatusUpdate'
				
	--select @Msg as Msg ,cast(1 as bit) as Flag

	select 'Statement "'+@StatementNumber+'" has been approved by you.
	your paymentis being processed and will be credited to your
	account in 5-6 days.you can track your payment in the
	Disbursements section.
	' as Msg ,cast(1 as bit) as Flag

Commit
End Try
Begin Catch
	if @@TRANCOUNT > 0
	Begin
		rollback;

		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select  @CompanyDetailID,'Seller Statement is not updated ',@StatementNumber,ERROR_MESSAGE(),GETDATE()

		select @Msg = LanguageError from [Register].[Language_Key] 
		where LanguageType = @LanguageType and LanguageKey = 'STATEMENTVIEW_SP_SellerStatement_StatusUpdateFailed'
				
		select @Msg as Msg ,cast(0 as bit) as Flag
		--select 'Seller Statement not added. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag
	End
End Catch
end  
GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Disbursement_Search]    Script Date: 11-04-2021 20:41:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--Exec Seller.usp_Payment_Disbursement_Search  @SearchBy='Paid',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Payment_Disbursement_Search] 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@CompanydetailID int
as
begin
	set nocount on;
	 
	 
	if(@SearchBy='All')
	begin

		Select StatementNumber,StatementDate,SettlementID,PSP_USDPaidToSeller PayoutAmount_USD,
		case when PSP_USDPaidToSeller is null then 'Under Process'
		when PSP_PaymentDateToSeller is not null then 'Completed' end PayoutStatus 
		,(Case when Statement_Approved_Status ='Agreed' and Approved_By=1 then 'Auto-Approved'
		when Statement_Approved_Status='Agreed' then 'Approved'
		When Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null then 'Raised Issue'
		Else Statement_Approved_Status End ) + 'Issue Number :'+isnull(SQ.ReferenceNumber,'') + '' Message 
		from Payment.Statements PS with(Nolock) 
		Inner Join Register.CompanyDetail CD With(Nolock) on CD.CompanyDetailID=PS.CompanyDetailID 
		Inner Join Payment.ReceiptsFileUploadLog RL With(Nolock) on RL.FileID=PS.ReceiptsFileID
		Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=PS.CompanyDetailID 
		and SQ.ReferenceNumber=PS.StatementNumber
		where PS.CompanyDetailID=@CompanyDetailID  
		and (ps.StatementNumber LIKE '%' + isnull(@Search,'') + '%') 
		order by 4 desc 
		for json path
	end
	else
	begin
		Select StatementNumber,StatementDate,SettlementID,PSP_USDPaidToSeller PayoutAmount_USD,
		case when PSP_USDPaidToSeller is null then 'Under Process'
		when PSP_PaymentDateToSeller is not null then 'Completed' end PayoutStatus  
		,(Case when Statement_Approved_Status ='Agreed' and Approved_By=1 then 'Auto-Approved'
		when Statement_Approved_Status='Agreed' then 'Approved'
		When Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null then 'Raised Issue'
		Else Statement_Approved_Status End ) + 'Issue Number :'+isnull(SQ.ReferenceNumber,'') + '' Message 
		from Payment.Statements PS with(Nolock) 
		Inner Join Register.CompanyDetail CD With(Nolock) on CD.CompanyDetailID=PS.CompanyDetailID 
		Inner Join Payment.ReceiptsFileUploadLog RL With(Nolock) on RL.FileID=PS.ReceiptsFileID
		Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=PS.CompanyDetailID 
		and SQ.ReferenceNumber=PS.StatementNumber
		where PS.CompanyDetailID=@CompanyDetailID   
		and (@SearchBy='Under Process' and PSP_USDPaidToSeller is null and (PS.StatementNumber LIKE '%' + isnull(@Search,'') + '%')  
		or (@SearchBy='Completed' and PSP_PaymentDateToSeller is not null   and (PS.StatementNumber LIKE '%' + isnull(@Search,'') + '%'))  
		) 
		order by 4 desc 
		for json path
	end
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Disbursement_View]    Script Date: 11-04-2021 20:41:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].usp_Payment_Disbursement_View 'J8J55YPHSC1',81
CREATE procedure [Seller].[usp_Payment_Disbursement_View]
@StatementNumber varchar(50),
@Companydetailid int
as
begin
	set nocount on;
	
	
	--declare @StatementNumber varchar(50)
	--declare @Companydetailid int

	--set @StatementNumber='J8J55YPHSC1'
	--set @Companydetailid='109'

	select TOP 1  StatementNumber StatementNumber
	,StatementDate StatementDate
	,CompanyName SellerName
	,CD.StoreName StoreName 
	,Convert(date,Approved_On,23) ScheduledPayout, 
	Convert(date,DateADD(Day,2,Approved_On),23)  PaymentReceivedbyPSP,
	Convert(Date,DATEADD(ms,DATEDIFF(ms,Approved_On, DateADD(Day,2,Approved_On))/2, Approved_On),23) UnderProcess ,
	Convert(date,PSP_PaymentDateToSeller,23) PaymentCompleted,
	PayableToMerchant AmountPayableINR,Isnull(PSP_USDPaidToSeller,0) AmountPayableUSD, 
	Isnull(PSP_USDToINRExchangeRate,0) INRtoUSDConversionRate,
	--iif(isnull(PaymentCompleted,'')='','5-6 business working days',Convert(date,PaymentCompleted,23)) Estimatedtimeofcompletion,
	'5-6 business working days' Estimatedtimeofcompletion,
	Cd.pspname PSP
	,case when PSP_USDPaidToSeller is null then 'Under Process'
	when PSP_PaymentDateToSeller is not null then 'Completed' end PayoutStatus
	from Payment.statements as s with(nolock) 
	inner join register.companydetail cd with(nolock) on cd.companydetailid=s.companydetailid 
	inner join Catalogue.SellerRegistration sr with(nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	where cd.companydetailid=@Companydetailid and s.StatementNumber=@StatementNumber
	for json path ,without_array_wrapper


	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Notification]    Script Date: 11-04-2021 20:41:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- exec [Seller].usp_Payment_Notification 81 
CREATE procedure  [Seller].[usp_Payment_Notification]
@CompanydetailID int
as
begin  
	set nocount on; 

	Select top 3 StatementCount,cast ( ActionDate as Date) ActionDate,StatementNumber,ActionMessage
	 from (
	select CompanyDetailID,count(StatementNumber) StatementCount,Max(StatementDate) ActionDate,Max(StatementNumber) StatementNumber, 
	'1 New Statement have been generated.' ActionMessage from Payment.Statements PS with(Nolock)
	Where CompanydetailID =@CompanydetailID AND convert(date,StatementDate,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,StatementDate having Count(StatementNumber)=1
	union all
	select CompanyDetailID,count(StatementNumber) StatementNumber,Max(StatementDate) ActionDate,'' StatementNumber, 
	convert(varchar(10),Count(StatementNumber))+' '+'New Statement have been generated.' ActionMsg from Payment.Statements PS with(Nolock)
	Where CompanydetailID =@CompanydetailID AND convert(date,StatementDate,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,StatementDate having Count(StatementNumber)>1
	union all 
	select CompanyDetailID,Count(StatementNumber) StatementNumber,Max(Convert(date,Approved_On,23)) ActionDate, Max(StatementNumber) Statementnumber,
	 convert(varchar(10),Count(StatementNumber))+' '+'New Statement have been Approved and It will be Moved to Disbursements.' msg   
	  from Payment.Statements PS with(Nolock)
	Where CompanydetailID =@CompanydetailID AND convert(date,Approved_On,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,Convert(date,Approved_On,23) having Count(StatementNumber)=1
	union all
	select CompanyDetailID,Count(StatementNumber) StatementNumber,Max(Convert(date,Approved_On,23)) ActionDate, '' Statementnumber, 
	convert(varchar(10),Count(StatementNumber))+' '+'New Statement have been Approved and It will be Moved to Disbursements.' msg    
	from Payment.Statements PS with(Nolock)
	Where CompanydetailID =@CompanydetailID AND convert(date,Approved_On,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,Convert(date,Approved_On,23) having Count(StatementNumber)>1
	union all
	select CompanyDetailID,Count(StatementNumber) StatementNumber,Max(Convert(date,PSP_PaymentDateToSeller,23)) ActionDate, 
	Max(Statementnumber) Statementnumber, convert(varchar(10),Count(StatementNumber))+' '+'Statements disbursement have been completed.' msg   
	from Payment.Statements PS with(Nolock)
	where CompanydetailID =@CompanydetailID AND PSP_PaymentDateToSeller is not null and  convert(date,PSP_PaymentDateToSeller,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,Convert(date,PSP_PaymentDateToSeller,23) having Count(StatementNumber)=1
	Union all
	select CompanyDetailID,Count(StatementNumber) StatementNumber,Max(Convert(date,PSP_PaymentDateToSeller,23)) ActionDate,'' Statementnumber,
	convert(varchar(10),Count(StatementNumber))+' '+'Statements disbursement have been completed.' msg   from Payment.Statements PS with(Nolock)
	where CompanydetailID =@CompanydetailID AND PSP_PaymentDateToSeller is not null and  convert(date,PSP_PaymentDateToSeller,23) >= convert(date,getdate()-7,23)
	group by CompanyDetailID,Convert(date,PSP_PaymentDateToSeller,23) having Count(StatementNumber)>1 ) PaymentNotifications 
	Order by ActionDate  
	for json path 

	set nocount off;

end

GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Report_Download]    Script Date: 11-04-2021 20:41:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [Seller].[usp_Payment_Report_Download]
@CompanyDetailID	CompanyDetailID, 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@StartDate varchar(10) = null,
@EndDate varchar(10) = null 
as
Begin

	set nocount on;
	 
	if (@SearchBy = 'Statements')
	Begin 
			Select CD.StoreName,Convert(date,R.ReceiptDate,23) ReceiptDate,Isnull(R.OrderID,'') OrderID,Isnull(R.SKU,'') MerchantSKU,R.OrderType,R.Qty Quantity,
			ISnull(R.Product_PrincipalAmount,0)+Isnull(R.Product_PrincipalTax,0)+Isnull(GiftWrap_PrincipalAmount,0)+  Isnull(GiftWrap_PrincipalTax,0)+Isnull(Shipping_PrincipalAmount,0)+
			Isnull(Shipping_PrincipalTax,0)+Isnull(Product_PrincipalTaxDiscount,0)+Isnull(Product_PrincipalDiscount,0)+Isnull(Shipping_PrincipalDiscount,0)+Isnull(Shipping_PrincipalTaxDiscount,0) TotalSales,
			Case When OrderType='other-transaction' and Expense=0 then 0 Else Isnull(R.Expense4payment,0)+Isnull(ExpenseTax4Payment,0) End Total_Amazon_Expense,
			Isnull(R.NetAmount,0) NetSales,Isnull(F.IORCommission,0)+Isnull(F.JenniferCommission,0)+Isnull(F.OtherCommission,0) IORCommission,
			ABS(Isnull(TaxAmountPerUnit,0))+ABS(Isnull(IGSTValuePerUnit,0)) IGST_Input_PerUnit,
			Case When OrderType='other-transaction' and Expense=0 then 0 Else ABS(Isnull(ExpenseTax4Payment,0))-ABS(Isnull(TCS_CGST,0))-ABS(IsNull(TCS_SGST,0))-ABS(IsNull(TCS_IGST,0)) End Expense_InputGST_PerUnit,
			ABS(Isnull(TCS_CGST,0))-ABS(IsNull(TCS_SGST,0))-ABS(IsNull(TCS_IGST,0)) TCS_InputGST_PerUnit, ABS(Isnull(F.GSTInputPerUnit,0)) Total_InputGST_PerUnit,ABS(Isnull(F.GSTOutPutPerUnit,0)) Total_OutPutGST_PerUnit,
			Isnull(F.GSTOutFlow,0) GST_OutFlow,Isnull(R.NetAmount,0)-(Isnull(F.IORCommission,0)+Isnull(F.JenniferCommission,0)+Isnull(F.OtherCommission,0))-Isnull(F.GSTOutFlow,0) NetPayable_Amount,
			S.StatementNumber Jennifer_StatementNumber
			from Payment.Receipts R With(NoLock) Inner Join Payment.Statements S With(NoLock) on S.ReceiptsFileID=R.PaymentDone4FileID and S.CompanyDetailID=R.CompanyDetailID
			Inner Join Register.CompanyDetail CD With(NoLock) on R.CompanyDetailID=CD.CompanyDetailID
			Inner Join (Select ReceiptID,Sum(Isnull(IORCommission,0)) IORCommission,Sum(Isnull(F.JenniferCommission,0)) JenniferCommission, Sum(Isnull(F.OtherCommission,0)) OtherCommission ,
			Sum(Isnull(F.GSTOutFlow,0)) GSTOutFlow,sum(ABS(Isnull(IGSTValuePerUnit,0))) IGSTValuePerUnit,Sum(ABS(Isnull(TaxAmountPerUnit,0))) TaxAmountPerUnit,Sum(ABS(Isnull(F.GSTInputPerUnit,0))) GSTInputPerUnit,
			Sum(ABS(Isnull(F.GSTOutPutPerUnit,0)))  GSTOutPutPerUnit
			from Payment.PurchaseFIFO F With(Nolock) Group by ReceiptID) F  on F.ReceiptID=R.ReceiptsID  
			where  R.PaymentDone4FileID is not null and R.CompanyDetailID=@CompanyDetailId 
			and r.ReceiptDate Between cast(@StartDate as datetime) and cast(@EndDate as datetime)
			for json path,include_null_values
			 
	End
	else if (@SearchBy = 'Statement')
	Begin 
			Select CD.StoreName,Convert(date,R.ReceiptDate,23) ReceiptDate,Isnull(R.OrderID,'') OrderID,Isnull(R.SKU,'') MerchantSKU,R.OrderType,R.Qty Quantity,
			ISnull(R.Product_PrincipalAmount,0)+Isnull(R.Product_PrincipalTax,0)+Isnull(GiftWrap_PrincipalAmount,0)+  Isnull(GiftWrap_PrincipalTax,0)+Isnull(Shipping_PrincipalAmount,0)+
			Isnull(Shipping_PrincipalTax,0)+Isnull(Product_PrincipalTaxDiscount,0)+Isnull(Product_PrincipalDiscount,0)+Isnull(Shipping_PrincipalDiscount,0)+Isnull(Shipping_PrincipalTaxDiscount,0) TotalSales,
			Case When OrderType='other-transaction' and Expense=0 then 0 Else Isnull(R.Expense4payment,0)+Isnull(ExpenseTax4Payment,0) End Total_Amazon_Expense,
			Isnull(R.NetAmount,0) NetSales,Isnull(F.IORCommission,0)+Isnull(F.JenniferCommission,0)+Isnull(F.OtherCommission,0) IORCommission,
			ABS(Isnull(TaxAmountPerUnit,0))+ABS(Isnull(IGSTValuePerUnit,0)) IGST_Input_PerUnit,
			Case When OrderType='other-transaction' and Expense=0 then 0 Else ABS(Isnull(ExpenseTax4Payment,0))-ABS(Isnull(TCS_CGST,0))-ABS(IsNull(TCS_SGST,0))-ABS(IsNull(TCS_IGST,0)) End Expense_InputGST_PerUnit,
			ABS(Isnull(TCS_CGST,0))-ABS(IsNull(TCS_SGST,0))-ABS(IsNull(TCS_IGST,0)) TCS_InputGST_PerUnit, ABS(Isnull(F.GSTInputPerUnit,0)) Total_InputGST_PerUnit,ABS(Isnull(F.GSTOutPutPerUnit,0)) Total_OutPutGST_PerUnit,
			Isnull(F.GSTOutFlow,0) GST_OutFlow,Isnull(R.NetAmount,0)-(Isnull(F.IORCommission,0)+Isnull(F.JenniferCommission,0)+Isnull(F.OtherCommission,0))-Isnull(F.GSTOutFlow,0) NetPayable_Amount,
			S.StatementNumber Jennifer_StatementNumber
			from Payment.Receipts R With(NoLock) Inner Join Payment.Statements S With(NoLock) on S.ReceiptsFileID=R.PaymentDone4FileID and S.CompanyDetailID=R.CompanyDetailID
			Inner Join Register.CompanyDetail CD With(NoLock) on R.CompanyDetailID=CD.CompanyDetailID
			Inner Join (Select ReceiptID,Sum(Isnull(IORCommission,0)) IORCommission,Sum(Isnull(F.JenniferCommission,0)) JenniferCommission, Sum(Isnull(F.OtherCommission,0)) OtherCommission ,
			Sum(Isnull(F.GSTOutFlow,0)) GSTOutFlow,sum(ABS(Isnull(IGSTValuePerUnit,0))) IGSTValuePerUnit,Sum(ABS(Isnull(TaxAmountPerUnit,0))) TaxAmountPerUnit,Sum(ABS(Isnull(F.GSTInputPerUnit,0))) GSTInputPerUnit,
			Sum(ABS(Isnull(F.GSTOutPutPerUnit,0)))  GSTOutPutPerUnit
			from Payment.PurchaseFIFO F With(Nolock) Group by ReceiptID) F  on F.ReceiptID=R.ReceiptsID  
			where  R.PaymentDone4FileID is not null and R.CompanyDetailID=@CompanyDetailId 
			and s.StatementNumber=isnull(@Search,'')
			for json path,include_null_values
	End 
	else if (@SearchBy = 'Transactions')
	Begin 
		Select top 1 * from register.users 
		where LastModifiedDate Between cast(@StartDate as datetime) and cast(@EndDate as datetime)
		for json path
	End
	else if (@SearchBy = 'TRANSACTIONSUMMARY')
	Begin  
		Select top 1 * from register.users 
		--where LastModifiedDate Between cast(@StartDate as datetime) and cast(@EndDate as datetime)
		for json path
	End 
	else if (@SearchBy = 'TRANSACTIONDETAILS')
	Begin  
		select 
		-- 'A' AColumn 
		"Detail 1"=(Select top 1 FirstName from register.users 
		--where LastModifiedDate Between cast(@StartDate as datetime) and cast(@EndDate as datetime)
		for json path) 
		,"Detail 2"=(Select top 2 FirstName from register.users 
		--where LastModifiedDate Between cast(@StartDate as datetime) and cast(@EndDate as datetime)
		for json path)
		 for json path 
	End
	set nocount off;
End

GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Statement_Search]    Script Date: 11-04-2021 20:41:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--Exec Seller.usp_Payment_Statement_Search  @SearchBy='Pending',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Payment_Statement_Search] 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@CompanydetailID int
as
begin
	set nocount on;
	 
	 
	if(@SearchBy='All')
	begin
		Select StatementNumber,StatementDate,PayableToMerchant, 
		Case when Statement_Approved_Status ='Agreed' and Approved_By=1 then 'Auto-Approved'
		when Statement_Approved_Status='Agreed' then 'Approved'
		When Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null then 'Raised Issue'
		Else Statement_Approved_Status End Status  
		,cast(24- datediff(hour, MailSentOn,getdate()) as varchar) + ' hrs left for auto-approval' Message
		from Payment.Statements PS with(Nolock) 
		Inner Join Register.CompanyDetail CD With(Nolock) on CD.CompanyDetailID=PS.CompanyDetailID 
		Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=PS.CompanyDetailID 
		and SQ.ReferenceNumber=PS.StatementNumber
		where PS.CompanydetailID=@CompanydetailID
		and (PS.StatementNumber LIKE '%' + isnull(@Search,'') + '%') 
		order by 4 desc
		for json path
	end
	else
	begin
		Select StatementNumber,StatementDate,PayableToMerchant, 
		Case when Statement_Approved_Status ='Agreed' and Approved_By=1 then 'Auto-Approved'
		when Statement_Approved_Status='Agreed' then 'Approved'
		When Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null then 'Raised Issue'
		Else Statement_Approved_Status End Status  
		,cast(24- datediff(hour, MailSentOn,getdate()) as varchar) + ' hrs left for auto-approval' Message
		from Payment.Statements PS with(Nolock) 
		Inner Join Register.CompanyDetail CD With(Nolock) on CD.CompanyDetailID=PS.CompanyDetailID 
		Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=PS.CompanyDetailID 
		and SQ.ReferenceNumber=PS.StatementNumber
		where PS.CompanydetailID=@CompanydetailID 
		and (@SearchBy='Pending' and Statement_Approved_Status='Pending' and SQ.ReferenceNumber is  null 
		and (PS.StatementNumber LIKE '%' + isnull(@Search,'') + '%') 
		or (@SearchBy='Raised Issue' and Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null 
		and (PS.StatementNumber LIKE '%' + isnull(@Search,'') + '%') )   
		) 
		order by 4 desc
		for json path
	end
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Statment_View]    Script Date: 11-04-2021 20:41:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- [Seller].usp_Payment_Statment_View 'J03V65OM12I',101
CREATE procedure [Seller].[usp_Payment_Statment_View]
@StatementNumber varchar(50),
@Companydetailid int
as
begin
	set nocount on;
	
	
	--declare @StatementNumber varchar(50)
	--declare @Companydetailid int

	--set @StatementNumber='J8J55YPHSC1'
	--set @Companydetailid='109'

	select top 1 @StatementNumber StatementNumber
	,Case when Statement_Approved_Status ='Agreed' and Approved_By=1 then 'Auto-Approved'
	when Statement_Approved_Status='Agreed' then 'Approved'
	When Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null then 'Raised Issue'
	Else Statement_Approved_Status End Status  
	,StatementDate StatementDate
	,CompanyName SellerName
	,CD.StoreName StoreName
	,cd.MarketPlaceSellerID MarketPlaceSellerID
	,lstEarnings=
	(
		SELECT HeadType,TransactionType,Amount,ReferenceID FROM 
		(
			Select 'Earnings' HeadType,
			'Amazon Credit' TransactionType,cast(AmazonCreditAmt as decimal(18,0)) Amount,SettlementID ReferenceID 
			from Payment.Statements PS with(nolock) 
			inner Join Payment.ReceiptsFileUploadLog UL With(Nolock) on PS.ReceiptsFileID=UL.FileID 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Earnings' HeadType, 
			'Balance Brought Forward' TransactionType, cast(PreviousAmazonCreditBalance as decimal(18,0))  Amount, 'rk needs to change' Ref 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Earnings' HeadType, 'Account Level Adjustments' TransactionType,
			cast(Isnull(FinAdjustmentAmtCredit,0) as decimal(18,0))   Amount, AdjustmentDescription Ref 
			from Payment.Statements PS with(nolock) 
			Left Join payment.FinancialAdjustment FA With(Nolock) on PS.StatementNumber=FA.StatementNumber 
			and PS.CompanyDetailID=FA.CompanyDetailID
			where FA.AdjustmentType='Credit'
			and PS.Companydetailid=@Companydetailid 
			and PS.StatementNumber=@StatementNumber
		) AS A
		for json path , include_null_values
	)
	,lstDeductions=
	(
		SELECT HeadType,TransactionType,Amount,ReferenceID FROM 
		(
			Select 'Deductions' HeadType, 
			'Opening Balance (Duties & Taxes)' TransactionType, cast(Isnull(OpeningBalance,0) as decimal(18,0))  Amount,
			 '' ReferenceID 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Deductions' HeadType, 'Duties & Taxes (IOR Investments)' TransactionType, 
			cast(Isnull(IORInvestments,0) as decimal(18,0))  Amount,
			 '' Ref 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Deductions' HeadType, 'Commissions' TransactionType, 
			cast(Isnull(IORCommission,0) + Isnull(JenniferCommission,0) + Isnull(OtherCommission,0) as decimal(18,0))  Amount, '' Ref 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Deductions' HeadType, 'Additional GST Overflow' TransactionType,
			cast(Isnull(GSTOutFlow,0) as decimal(18,0))   Amount, '' Ref 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
			Union all 
			Select 'Deductions' HeadType, 'Account Level Reserve' TransactionType, 
			cast(Isnull(Adjustments,0)  as decimal(18,0))  Amount, '' Ref 
			from Payment.Statements PS with(nolock) 
			where PS.Companydetailid=@Companydetailid and StatementNumber=@StatementNumber
		) AS A
		for json path , include_null_values
	)
	from Payment.statements as s with(nolock) 
	inner join register.companydetail cd with(nolock) on cd.companydetailid=s.companydetailid 
	inner join Catalogue.SellerRegistration sr with(nolock) on sr.MarketPlaceSellerID=cd.MarketPlaceSellerID
	Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=s.CompanyDetailID and SQ.ReferenceNumber=s.StatementNumber 
	where cd.companydetailid=@Companydetailid and s.StatementNumber=@StatementNumber
	for json path ,without_array_wrapper


	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Status]    Script Date: 11-04-2021 20:41:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 -- exec [Seller].usp_Payment_Status 81 
CREATE procedure  [Seller].[usp_Payment_Status]
@CompanydetailID int
as
begin  
	set nocount on; 

	select PaymentStatus,StatusCount from
	(
		select 'Pending' PaymentStatus,	count(Statement_Approved_Status) StatusCount 
		from Payment.Statements with (nolock)	
		where CompanydetailID=@CompanydetailID   
		and Statement_Approved_Status='Pending'
		union all
		select 'Raised Issues' PaymentStatus,	count(Statement_Approved_Status) StatusCount 
		from Payment.Statements PS with (nolock)	
		Left join  Register.SupportQuery SQ with(Nolock) on SQ.CompanyDetailID=PS.CompanyDetailID and SQ.ReferenceNumber=PS.StatementNumber
		where PS.CompanydetailID=@CompanydetailID   
		and Statement_Approved_Status<>'Agreed' and SQ.ReferenceNumber is not null
		union all
		select 'Under Process' PaymentStatus,	count(Statement_Approved_Status) StatusCount 
		from Payment.Statements with (nolock)	
		where CompanydetailID=@CompanydetailID   
		and PSP_USDPaidToSeller is null
		union all
		select 'Completed' PaymentStatus,	count(Statement_Approved_Status) StatusCount 
		from Payment.Statements with (nolock)	
		where CompanydetailID=@CompanydetailID   
		and PSP_PaymentDateToSeller is not null
	) 
	 as a for json path 

	set nocount off;

end

GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Transaction_Search]    Script Date: 11-04-2021 20:41:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Exec Seller.usp_Payment_Transaction_Search  @SearchBy='Pending',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Payment_Transaction_Search] 
@SearchBy varchar(100) = '', 
@Search varchar(100) = '', 
@CompanyDetailID int
as
begin
	set nocount on;

	--FBA SHIPMENT ID	SHIPMENT VALUE	PAID VALUE	REMAINING VALUE	STATUS 

	if(@SearchBy='All')
	begin
		 
		Select ShipmentNumber FBAShipmentID,ShipmentDate,ShipmentValue,ShipmentPaid PaidValue ,RemainingBal RemainingValue
		,case When RemainingBal<0 Then 'Paid Excess' 
		When RemainingBal>=0 and RemainingBal<=5 then 'Paid'
		When RemainingBal<ShipmentValue then 'Partially Paid'
		When ShipmentPaid<=5 Then 'Overdue'
		End Status  
		from Payment.ShipmentTransactions as a with (nolock)
		where CompanyDetailID!=@CompanyDetailID  
		and (a.ShipmentNumber LIKE '%' + isnull(@Search,'') + '%')
		order by a.ShipmentNumber desc
		for json path
	end
	else
	begin
		Select ShipmentNumber FBAShipmentID,ShipmentDate,ShipmentValue,ShipmentPaid PaidValue ,RemainingBal RemainingValue
		,case When RemainingBal<0 Then 'Paid Excess' 
		When RemainingBal>=0 and RemainingBal<=5 then 'Paid'
		When RemainingBal<ShipmentValue then 'Partially Paid'
		When ShipmentPaid<=5 Then 'Overdue'
		End Status  
		from Payment.ShipmentTransactions as a with (nolock)
		where CompanyDetailID!=@CompanyDetailID   
		and 
		(case When RemainingBal<0 Then 'Paid Excess' 
		When RemainingBal>=0 and RemainingBal<=5 then 'Paid'
		When RemainingBal<ShipmentValue then 'Partially Paid'
		When ShipmentPaid<=5 Then 'Overdue'
		End )=@SearchBy and a.ShipmentNumber LIKE '%' + isnull(@Search,'') + '%' 
		order by a.ShipmentNumber desc
		for json path
	end
	

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Payment_Transaction_View]    Script Date: 11-04-2021 20:41:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Exec Seller.usp_Payment_Transaction_View  @SearchBy='Pending',@Search='',@SellerFormID='81'
CREATE procedure [Seller].[usp_Payment_Transaction_View] 
@FBAShipmentID varchar(100) = '',  
@CompanyDetailID int
as
begin
	set nocount on;
	 
	----puneeth query
	----- Invoice Details
	--select  top 1 
	--PM.InvoiceNumber, 
	--isnull(sum(PC.DirectCost),0) + IIF(Max(BOE.DutyMode) = 'DDP', isnull(Sum(P.InvestmentPerUnit),0),0)  InvoiceValue 
	--from Purchase.Shipment M With(nolock) inner join Purchase.Invoice PM With(nolock) on M.CompanyDetailID = PM.CompanyDetailID and M.POID = PM.POID
	--inner join Purchase.InvoiceItem PC With(nolock) on PC.CompanyDetailID = PM.CompanyDetailID and PC.PurchaseID = PM.PurchaseID
	--inner join Purchase.[Order] PO With(nolock) on PO.CompanyDetailID = PM.CompanyDetailID and PO.POID = PM.POID and PO.IsPOClosed = 1
	--inner join Purchase.BOEHeader BOE With(nolock) on BOE.CompanyDetailId = PM.CompanyDetailID and BOE.PurchaseID = PM.PurchaseID
	--Cross Apply (select Sum(InvestmentPerUnit) InvestmentPerUnit  from Payment.PurchaseFIFO PF With(nolock) Where PF.PurchaseInvItemID = PC.PurchaseInvItemID and PF.CompanyDetailID = PC.CompanyDetailId)P
	--Inner Join Register.CompanyDetail CD with(Nolock) on CD.CompanyDetailID=M.CompanyDetailID
	--Where CD.CompanyID=3 
	--and cd.CompanydetailID=101
	--group by M.ShipmentNumber,CD.CompanydetailID,Convert(date,M.LastModifiedDate,23),PSPName  ,PM.InvoiceNumber
	--Order by 1 
	----- investment Details  
	--select  top 1 
	--IIF(Max(BOE.DutyMode) <> 'DDP', isnull(Sum(P.InvestmentPerUnit),0),0) ToalCustomsDuty,
	--isnull(Sum(P.CustomsDuty),0) CustomsDuty, isnull(Sum(P.IGSTTax),0) IGSTTax,0 Others 
	--from Purchase.Shipment M With(nolock) inner join Purchase.Invoice PM With(nolock) on M.CompanyDetailID = PM.CompanyDetailID and M.POID = PM.POID
	--inner join Purchase.InvoiceItem PC With(nolock) on PC.CompanyDetailID = PM.CompanyDetailID and PC.PurchaseID = PM.PurchaseID
	--inner join Purchase.[Order] PO With(nolock) on PO.CompanyDetailID = PM.CompanyDetailID and PO.POID = PM.POID and PO.IsPOClosed = 1
	--inner join Purchase.BOEHeader BOE With(nolock) on BOE.CompanyDetailId = PM.CompanyDetailID and BOE.PurchaseID = PM.PurchaseID
	--Cross Apply (select Sum(InvestmentPerUnit) InvestmentPerUnit,Sum(isnull(TotalDutyPerUnit,0)) CustomsDuty,Sum(isnull(IGSTValuePerUnit,0))+Sum(isnull(TaxAmountPerUnit,0)) IGSTTax  from Payment.PurchaseFIFO PF With(nolock) Where PF.PurchaseInvItemID = PC.PurchaseInvItemID and PF.CompanyDetailID = PC.CompanyDetailId)P
	--Inner Join Register.CompanyDetail CD with(Nolock) on CD.CompanyDetailID=M.CompanyDetailID
	--Where CD.CompanyID=3 
	--group by M.ShipmentNumber,CD.CompanydetailID,Convert(date,M.LastModifiedDate,23),PSPName  
	--Order by 1

	select top 1 @FBAShipmentID FBAShipmentID 
	,case When RemainingBal<0 Then 'Paid Excess' 
	When RemainingBal>=0 and RemainingBal<=5 then 'Paid'
	When RemainingBal<ShipmentValue then 'Partially Paid'
	When ShipmentPaid<=5 Then 'Overdue'
	End Status  
	,lstInvoices=
	(
		SELECT InvoiceNumber,InvoiceValue FROM 
		(
			select 
			PM.InvoiceNumber, 
			isnull(sum(PC.DirectCost),0) + IIF(Max(BOE.DutyMode) = 'DDP', isnull(Sum(P.InvestmentPerUnit),0),0)  InvoiceValue 
			from Purchase.Shipment M With(nolock) inner join Purchase.Invoice PM With(nolock) on M.CompanyDetailID = PM.CompanyDetailID and M.POID = PM.POID
			inner join Purchase.InvoiceItem PC With(nolock) on PC.CompanyDetailID = PM.CompanyDetailID and PC.PurchaseID = PM.PurchaseID
			inner join Purchase.[Order] PO With(nolock) on PO.CompanyDetailID = PM.CompanyDetailID and PO.POID = PM.POID and PO.IsPOClosed = 1
			inner join Purchase.BOEHeader BOE With(nolock) on BOE.CompanyDetailId = PM.CompanyDetailID and BOE.PurchaseID = PM.PurchaseID
			Cross Apply (select Sum(InvestmentPerUnit) InvestmentPerUnit  from Payment.PurchaseFIFO PF With(nolock) Where PF.PurchaseInvItemID = PC.PurchaseInvItemID and PF.CompanyDetailID = PC.CompanyDetailId)P
			Inner Join Register.CompanyDetail CD with(Nolock) on CD.CompanyDetailID=M.CompanyDetailID
			Where m.Companydetailid=@Companydetailid
			and m.ShipmentNumber=@FBAShipmentID
			group by M.ShipmentNumber,CD.CompanydetailID,Convert(date,M.LastModifiedDate,23),PSPName  ,PM.InvoiceNumber 
		) AS A 
		Order by 1 
		for json path , include_null_values
	)
	,lstInvestments=
	(
		SELECT ToalCustomsDuty,CustomsDuty,IGSTTax,Others FROM 
		(
			select 
			IIF(Max(BOE.DutyMode) <> 'DDP', isnull(Sum(P.InvestmentPerUnit),0),0) ToalCustomsDuty,
			isnull(Sum(P.CustomsDuty),0) CustomsDuty, isnull(Sum(P.IGSTTax),0) IGSTTax,0 Others 
			from Purchase.Shipment M With(nolock) inner join Purchase.Invoice PM With(nolock) on M.CompanyDetailID = PM.CompanyDetailID and M.POID = PM.POID
			inner join Purchase.InvoiceItem PC With(nolock) on PC.CompanyDetailID = PM.CompanyDetailID and PC.PurchaseID = PM.PurchaseID
			inner join Purchase.[Order] PO With(nolock) on PO.CompanyDetailID = PM.CompanyDetailID and PO.POID = PM.POID and PO.IsPOClosed = 1
			inner join Purchase.BOEHeader BOE With(nolock) on BOE.CompanyDetailId = PM.CompanyDetailID and BOE.PurchaseID = PM.PurchaseID
			Cross Apply (select Sum(InvestmentPerUnit) InvestmentPerUnit,Sum(isnull(TotalDutyPerUnit,0)) CustomsDuty,Sum(isnull(IGSTValuePerUnit,0))+Sum(isnull(TaxAmountPerUnit,0)) IGSTTax  from Payment.PurchaseFIFO PF With(nolock) Where PF.PurchaseInvItemID = PC.PurchaseInvItemID and PF.CompanyDetailID = PC.CompanyDetailId)P
			Inner Join Register.CompanyDetail CD with(Nolock) on CD.CompanyDetailID=M.CompanyDetailID
			Where CD.CompanydetailID=@CompanydetailID
			and m.ShipmentNumber=@FBAShipmentID
			group by M.ShipmentNumber,CD.CompanydetailID,Convert(date,M.LastModifiedDate,23),PSPName  
		) AS A
		Order by 1
		for json path , include_null_values
	)
	from Purchase.Shipment as s with(nolock) 
	inner join register.companydetail cd with(nolock) on cd.companydetailid=s.companydetailid  
	inner join Payment.ShipmentTransactions as a with (nolock) on a.companydetailid=s.companydetailid  and a.ShipmentNumber=s.ShipmentNumber
	where s.companydetailid=@Companydetailid and s.ShipmentNumber=@FBAShipmentID
	for json path ,without_array_wrapper
	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Preference_Language_Update]    Script Date: 11-04-2021 20:41:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create procedure [Seller].[usp_Preference_Language_Update]  
@json varchar(max)
as
begin
begin try

	begin transaction
	 

	set @json = CONCAT('[', @json, ']')
	  
	  
	declare @LoginId  UserID 
	declare @SellerFormID int
	declare @PreferLanguage varchar(10) 	
	
	set @LoginId = JSON_VALUE(@json, '$[0].LoginId') 
	set @SellerFormID = JSON_VALUE(@json, '$[0].SellerFormID')
	set @PreferLanguage = JSON_VALUE(@json, '$[0].PreferLanguage') 


	if not exists (select 1 from Seller.Preference where SellerFormID=@SellerFormID)
	begin
		
		insert into Seller.Preference (SellerFormID,PreferLanguage,LastModifiedBy,LastModifiedDate)
		select @SellerFormID,@PreferLanguage,@LoginId,getdate() 

		select 'Language  setting has been added!' as Msg ,cast(1 as bit) as Flag  
	end
	else
	begin
		
		update Seller.Preference set 
		PreferLanguage=@PreferLanguage, 
		LastModifiedBy=@LoginId,
		LastModifiedDate=getdate()
		where SellerFormID=@SellerFormID 
		 
		select 'Language setting has been updated!' as Msg ,cast(1 as bit) as Flag  
	end

	commit



end try 
begin catch

	if @@TRANCOUNT > 0 
	Begin 
		rollback; 
		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate) 
		select  @SellerFormID,'Language -','',ERROR_MESSAGE(),GETDATE() 

		select 'Action Failed. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag  

	End

end catch
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Preference_Search]    Script Date: 11-04-2021 20:41:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [Seller].[usp_Preference_Search]  
@SellerFormID int,
@LoginID int
as
begin
	set nocount on;
	 
	select PreferLanguage,Newstatementgenerated,PaymentreceivedbyPSP
	,Paymentcomplete,Productsrequestedtoresend,Productsapproved,ProductsOutofStock
	,ShipmentpendingCARPupload,Shipmentrequestedtoresend,Shipmentcompleted,Generateandsendreports
	from Seller.Preference with (nolock)
	where  SellerFormID=@SellerFormID 
	for json path,without_array_wrapper

	set nocount off;
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_Preference_Update]    Script Date: 11-04-2021 20:41:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 CREATE procedure [Seller].[usp_Preference_Update]  
@json varchar(max)
as
begin
begin try

	begin transaction
	 

	set @json = CONCAT('[', @json, ']')
	  
	  
	declare @LoginId  UserID 
	declare @SellerFormID int
	declare @PreferLanguage varchar(10)
	declare @Newstatementgenerated varchar(10)
	declare @PaymentreceivedbyPSP varchar(10)
			
	declare @Paymentcomplete varchar(10)
	declare @Productsrequestedtoresend varchar(10)
	declare @Productsapproved varchar(10)
	declare @ProductsOutofStock varchar(10)
	declare @ShipmentpendingCARPupload varchar(10)

	declare @Shipmentrequestedtoresend varchar(10)
	declare @Shipmentcompleted varchar(10) 
	declare @Generateandsendreports varchar(10)			
	
	set @LoginId = JSON_VALUE(@json, '$[0].LoginId') 
	set @SellerFormID = JSON_VALUE(@json, '$[0].SellerFormID')
	set @PreferLanguage = JSON_VALUE(@json, '$[0].PreferLanguage')
	set @Newstatementgenerated = JSON_VALUE(@json, '$[0].Newstatementgenerated') 
	set @PaymentreceivedbyPSP = JSON_VALUE(@json, '$[0].PaymentreceivedbyPSP')

	set @Paymentcomplete = JSON_VALUE(@json, '$[0].Paymentcomplete')
	set @Productsrequestedtoresend = JSON_VALUE(@json, '$[0].Productsrequestedtoresend') 
	set @Productsapproved = JSON_VALUE(@json, '$[0].Productsapproved')
	set @ProductsOutofStock = JSON_VALUE(@json, '$[0].ProductsOutofStock')
	set @ShipmentpendingCARPupload=JSON_VALUE(@json, '$[0].ShipmentpendingCARPupload')

	set @Shipmentrequestedtoresend = JSON_VALUE(@json, '$[0].Shipmentrequestedtoresend') 
	set @Shipmentcompleted = JSON_VALUE(@json, '$[0].Shipmentcompleted') 
	set @Generateandsendreports = JSON_VALUE(@json, '$[0].Generateandsendreports') 


	if not exists (select 1 from Seller.Preference where SellerFormID=@SellerFormID)
	begin
		
		insert into Seller.Preference (SellerFormID,PreferLanguage,Newstatementgenerated,PaymentreceivedbyPSP,Paymentcomplete
		,Productsrequestedtoresend,Productsapproved,ProductsOutofStock,ShipmentpendingCARPupload,Shipmentrequestedtoresend
		,Shipmentcompleted,Generateandsendreports,LastModifiedBy,LastModifiedDate)
		select @SellerFormID,@PreferLanguage,@Newstatementgenerated,@PaymentreceivedbyPSP,@Paymentcomplete
		,@Productsrequestedtoresend,@Productsapproved,@ProductsOutofStock,@ShipmentpendingCARPupload,@Shipmentrequestedtoresend
		,@Shipmentcompleted,@Generateandsendreports,@LoginId,getdate()


		select 'Notification preference and Language setting has been added!' as Msg ,cast(1 as bit) as Flag  
	end
	else
	begin
		
		update Seller.Preference set 
		PreferLanguage=@PreferLanguage,
		Newstatementgenerated=@Newstatementgenerated,
		PaymentreceivedbyPSP=@PaymentreceivedbyPSP,
		Paymentcomplete=@Paymentcomplete,
		Productsrequestedtoresend=@Productsrequestedtoresend,
		Productsapproved=@Productsapproved,
		ProductsOutofStock=@ProductsOutofStock,
		ShipmentpendingCARPupload=@ShipmentpendingCARPupload,
		Shipmentrequestedtoresend=@Shipmentrequestedtoresend,
		Shipmentcompleted=@Shipmentcompleted,
		LastModifiedBy=@LoginId,
		LastModifiedDate=getdate()
		where SellerFormID=@SellerFormID
		 
		 
		select 'Notification preference and Language setting has been updated!' as Msg ,cast(1 as bit) as Flag  
	end

	commit



end try 
begin catch

	if @@TRANCOUNT > 0 
	Begin 
		rollback; 
		insert into  Register.ErrorLog(CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate) 
		select  @SellerFormID,'Preference -','',ERROR_MESSAGE(),GETDATE() 

		select 'Action Failed. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag  

	End

end catch
end 


GO

/****** Object:  StoredProcedure [Seller].[usp_User_Delete]    Script Date: 11-04-2021 20:41:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create proc [Seller].[usp_User_Delete]  
@Id int,
@LoginId UserId
As
Begin
Begin Try
	Begin Tran    

		Update Register.UserPermission Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()   where UserId=@Id 
		Update Register.UserAuthToken Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()   where UserId=@Id 
		Update Register.UserLogDetails Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()  where UserId=@Id 
		Update Register.UserCompanyDetail Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()   where UserId=@Id 
		Update   Masters.UserMasterUpload Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()  where UserId=@Id 
		Update   Register.Users Set  
		LastModifiedBy=@LoginId,LastModifiedDate=getdate()  where UserId=@Id 


		Delete from Register.UserPermission where UserId=@Id 
		Delete from Register.UserAuthToken where UserId=@Id 
		Delete from Register.UserLogDetails where UserId=@Id 
		Delete from Register.UserCompanyDetail where UserId=@Id 
		Delete from Masters.UserMasterUpload where UserId=@Id 
		Delete from Register.Users  where UserId=@Id 
		 
		select 'User has been deleted successfully' as Msg ,cast(1 as bit) as Flag
	Commit
End Try
Begin Catch
	if @@TRANCOUNT > 0
	Begin
		rollback;

		insert into Register.ErrorLog(CompanyID,CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select null,null,'User Delete',@Id,ERROR_MESSAGE(),GETDATE()

		select 'User not deleted. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag
	End
End Catch
End
 

GO

/****** Object:  StoredProcedure [Seller].[usp_User_Insert]    Script Date: 11-04-2021 20:41:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [Seller].[usp_User_Insert]
@FirstName varchar(30),
@Email  Email,
@Password binary(32), 
@Salt varchar(100), 
@LoginId UserId,

@UserType varchar(2)
As
Begin
Begin Try
	Begin Tran    
	  
	declare @Id int 
	declare @iusertype int;
	declare @Msg nvarchar(1000)

	
	declare @SellerFormID int 

	select @SellerFormID=SellerFormID from Register.Users WITH (NOLOCK)  where UserId=@LoginId
	 
	set @iusertype='4';
	-- Seller Admin
	if exists (select 1 from Register.UserCompanyDetail WITH (NOLOCK) where UserId=@LoginId)
	begin
		if ((select count(UserId) from Register.Users U WITH (NOLOCK) where SellerFormID=@SellerFormID and U.UserType = 4) <2)
		begin
				
			if not exists(select 1 from Register.Users WITH (NOLOCK)  where Email=@Email)
			begin

				Insert into Register.Users 
				(FirstName,LastName,Email,Password,Salt,UserType,Isactive,LastModifiedBy,LastModifiedDate,SellerFormID)  
				Values
				(@FirstName,null,@Email,@Password,@Salt,@iusertype,1,@LoginId,getdate(),@SellerFormID)

				set @Id= cast(scope_identity() as int)

				-- Assigning all store into users from admins 
				insert into Register.UserCompanyDetail (UserId,CompanyDetailID,IsActive,LastModifiedBy,LastModifiedDate)
				select @Id,CompanyDetailID,IsActive,@LoginId,getdate() from Register.UserCompanyDetail where UserId=@LoginId 

				insert into register.userpermission (MenuID,UserId,IsViewEdit,LastModifiedBy,LastModifiedDate)
				select distinct menuid,@Id,'2',@LoginId,GETDATE() from register.UserTypeMenu as t where usertype = @iusertype
				and not exists (select 1 from register.userpermission as m where m.MenuID=t.MenuID and m.userid=@Id)
				 
				select 'Seller has been added successfully' as Msg ,cast(1 as bit) as Flag 
			end
			else
			begin 
				select 'Email: '+@Email+' Already Exist.' as Msg ,cast(0 as bit) as Flag 
			end
		end
		else
		begin 
			select 'You can''t add more than 2 users.! Please contact jennifer support for further queries.' as Msg ,cast(0 as bit) as Flag 
		end
	end
	begin 
		select 'You can''t add users at this time.! Please update the Amazon seller information to proceed further.' as Msg ,cast(0 as bit) as Flag
	end 

	Commit
End Try
Begin Catch
	if @@TRANCOUNT > 0
	Begin
		rollback;
		insert into Register.ErrorLog(CompanyID,CompanyDetailID,ScreenName,UniqueNumber,ErrorMessage,CreatedDate)
		select null,null,'User Insert',@Email,ERROR_MESSAGE(),GETDATE()
		 
		select 'User not saved. Please try again after sometime.!' as Msg ,cast(0 as bit) as Flag
		 
	End
End Catch
End

GO

/****** Object:  StoredProcedure [Seller].[usp_User_Search]    Script Date: 11-04-2021 20:41:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [Seller].[usp_User_Search]
@SellerFormID int,
@LoginID UserID 
As
Begin
	set nocount on;

	Select U.UserId,isnull(FirstName,'') + ' ' + isnull(LastName,'') FirstName,
	Email, UserType,
	iif(isnull(U.IsActive,0)=0,'InActive','Active') Status
	from Register.Users as u  with (nolock)       
	where u.SellerFormID=@SellerFormID  
	for json path

	set nocount off;
End


GO

/****** Object:  StoredProcedure [Seller].[usp_Video_Search]    Script Date: 11-04-2021 20:41:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create procedure [Seller].[usp_Video_Search] 
@Search varchar(100) = '',
@SellerFormID int,
@LoginID int
as
begin
	set nocount on;
	 
	select VideoID,Category,URLPath,ShortDescription,LongDescription 
	from Seller.[Video] with (nolock)
	where IsActive = 1 and 
	((ShortDescription like '%' + isnull(@Search,'') + '%')
	or (LongDescription like '%' + isnull(@Search,'') + '%') 
	or (Category like '%' + isnull(@Search,'') + '%') 
	)
	for json path

	set nocount off;
end 

GO


