Declare @ShortCodeGuid as UNIQUEIDENTIFIER = '020aa42b-2f22-4273-87dc-c88fb77c1c92'
DECLARE @PAGEGUID AS UNIQUEIDENTIFIER = '8c586b41-5861-46c3-91df-d2f2c2e5046c'
Declare @BlockGuid as UNIQUEIDENTIFIER = 'c155625d-0cd2-478e-9ae7-b2936beede0e'
Declare @HTMLContent as UNIQUEIDENTIFIER = 'da77eec7-bc4e-46dd-9771-a72090e31b74'



DELETE
From LavaShortCode
Where [Guid] = @ShortCodeGuid

Delete From 
[Page]
Where [Guid] = @PAGEGUID

DELETE From
[Block]
Where [Guid] = @BlockGuid

Delete From
[HtmlContent]
Where [Guid] = @HTMLContent