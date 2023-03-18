Declare @ShortCodeGuid as UNIQUEIDENTIFIER = '020aa42b-2f22-4273-87dc-c88fb77c1c92'
DECLARE @PAGEGUID AS UNIQUEIDENTIFIER = '8c586b41-5861-46c3-91df-d2f2c2e5046c'
Declare @BlockGuid as UNIQUEIDENTIFIER = 'c155625d-0cd2-478e-9ae7-b2936beede0e'
Declare @HTMLContent as UNIQUEIDENTIFIER = 'da77eec7-bc4e-46dd-9771-a72090e31b74'

-- Creates the Entity Attribute used by the plugin to mark transactions as reconciled.
Insert Into Attribute
([IsSystem], [FieldTypeId],[EntityTypeId],[Key],[Name],[Description],[Order],[IsGridColumn],[DefaultValue],[IsMultiValue],[IsRequired],[Guid],[AllowSearch],[IsIndexEnabled],[IsAnalytic],[IsAnalyticHistory],[IsActive],[EnableHistory])
VALUES
(0,11,84,'ReconciledOn','Reconciled On','This Entity Attribute is used to mark when an online transaction has been reconciled.  It is used in the NMI Batch Reconcilation Plugin','',0,'',0,0,NewId(),0,0,0,0,1,0)


--Short Code Markup

Declare @Documentation VARCHAR(MAX) = '{[ batchlist daysback:''15'' depositaccountname:''Citizens E-Checking'' depositaccountglcode:'''']}'

Declare @markup VARCHAR(MAX) = '<div id="batches"></div>

<script>

let url = ''/Webhooks/Lava.ashx/nmiplugin/nmitransactionmatch/{{CurrentPerson.Guid}}/{{daysback}}''


   
   
   
   async function updateAttribute(item, batchid) {
           let today = getFormattedDate(new Date())
           let  reconcileurl = `/api/FinancialTransactions/AttributeValue/${item}?attributeKey=ReconciledOn&attributeValue=${today}`
           await fetch(reconcileurl, {
                         method: ''POST'',
                       })
           .then(response => {
           
                   $(''#confirmbatch-''+ batchid).addClass("hide");
                   $(''#printbatch-''+ batchid).removeClass("hide");
                   
                   addconfirmed(item, today)
           
           })
           .catch(error => console.error(''Error:'', error));
 }
 
   function addconfirmed(item, today){
       document.getElementById(item).innerHTML = `${today}`
   }

async function  getTransactions(url) {
   
   // Fetch Data from API and Convert to JSON
      const response =  await fetch(url)
      const transactions = await response.json()
      
      
      console.time()
      // Return keys sorted by date
       let sortedKeys = []
       // let sorted =  _.orderBy(transactions,''date'',''desc'')
       let sorted =  transactions.sort(compare)

       sorted.forEach((x) =>{

           const isInArray = sortedKeys.includes(x.batchid);
           
           if(sortedKeys.indexOf(x.batchid) == -1) {
           sortedKeys.push(x.batchid)
           }
       })
       
       //Group Transactions into Batches
       let groupedBatch = []
       sortedKeys.forEach(function(batchid) {
               let batchobject = {}
               batchobject.batchid = batchid; 
               
               
               //Filter Transactions based on provided Key
               let batch = transactions.filter(transaction => transaction.batchid === batchid);
               
               //calculate Batch Total
               let Total = batch.reduce(function(a,b){
                   return a + parseInt(b.amount)
               },0)
               
               



               //Set Batch Date, Total, and BatchData
               batchobject.date = batch[0].date                
               batchobject.Total = Total
               batchobject.transactions = batch

               let accounts =[]
               
               batchobject.transactions.forEach(function(transaction){
                   transaction.RockData.forEach(function(el){
                       el.Accounts.forEach(function(e){
                           accounts.push(e)
                       })
                   })
               })


               //Push Batch Object into Grouped Batches
               groupedBatch.push(batchobject)

       })

       for (let batch of groupedBatch){
           document.getElementById(''batches'').innerHTML += buildBatchOutput(batch)
        }
        

       
}

function group(list, prop) {  
   return list.reduce(function(grouped, item) {
       var key = isFunction(prop) ? prop.apply(this, [item]) : item[prop];
       grouped[key] = grouped[key] || [];
       grouped[key].push(item);
       return grouped;
   }, {});
 }


 function compare(a,b) {
   return b.date-a.date;
}

function buildBatchOutput(batch){

   let heading =  assembleHeading(batch)
   let body = assembleBody(batch)

   
   return heading + body
}

function assembleHeading(batch) {
    console.log(batch.transactions)
   
   let reconciledCount = batch.transactions.filter(transaction => transaction.RockData[0].Reconciled !== '''').length

   let date = convertDate(batch.date)
   let transactionlist = []
   
   batch.transactions.forEach(function(element){
       
       transactionlist.push(element.RockData[0].TransactionId)
   })
  
   let type = ''Deposit''
   if(batch.Total < 0 ) {
       let type = ''Withdrawal''
   }
   
   let reconciledcheck = checkReconciledCount(reconciledCount, batch.transactions.length)

   let htmlPanelHeading = `<div class="panel panel-default hidden-print" style="page-break-inside:avoid;" id="${batch.batchid}">`
   
   htmlPanelHeading += `
                   <div class="panel-heading" style="display:flex; flex-direction:column; justify-content: space-between;">
                       <div style="display:flex; flex-direction: row; justify-content: space-between; margin-bottom:20px;">
                           <h4 class="batchid" style="margin:0">Date: ${getFormattedDate(date)}</h4>
                           <h4 class="batchid" style="margin:0; text-align:right;"><span class="transactioncount ${type}" style="margin-bottom: 20px;">{{depositaccountname}}<br>
                                   ${type}: $${batch.Total.toFixed(2)}
                               </span></h4>
                       </div>
                       <div style="display:flex; flex-direction: row; justify-content: space-between; margin-bottom:20px;">
                           <h5 style="margin:0">Batch Id: ${batch.batchid}</h5>
                           <h5 style="margin:0">Transaction Count: ${batch.transactions.length}</h5>
                       </div>
                       <div style="display:flex; flex-direction: row; justify-content: space-between;">
                           <ul class="nav nav-pills" style="max-width:50%;">
                               <li class="active"><a data-toggle="pill" href="#FundActivity-${batch.batchid}">Fund Activity</a></li>
                               <li class="hidden-print"><a data-toggle="pill" href="#transactions-${batch.batchid}">Transactions</a></li>
                               <li><a id="confirmbatch-${batch.batchid}" class="${reconciledcheck ? ''hide'' : ''''}" onclick="finalizedeposit(${createTransactionListString(transactionlist)},''${batch.batchid}'')">Confirm
                                       Deposit</a></li>
                           </ul>

                           <div class="hidden-print ${reconciledcheck ? '''' : ''hide''}" id="printbatch-${batch.batchid}">
                               <input type="checkbox" onclick="onCheck(''${batch.batchid}'')" id="${batch.batchid}-print" name="${batch.batchid}-IncludeInPrint" value="Print">
                               <label for="${batch.batchid}-IncludeInPrint">Include In Print</label>
                           </div>
                       </div>
                   </div>
   `
 


   return htmlPanelHeading 
   
}

function assembleBody(batch) {
   
   let accounts =[]

   batch.transactions.forEach(function(transaction){
       transaction.RockData.forEach(function(el){
           el.Accounts.forEach(function(e){
               accounts.push(e)
           })
       })
   })
   let fundData = getFundActivity(accounts, batch)

   let htmlbodyFundActivity = `<div class="panel-body">
       <div class="tab-content">
         <div id="FundActivity-${batch.batchid}" class="tab-pane fade in active">
           <table class="table table-striped table-hover" style="font-size:1.1em; max-width:50%; min-width:320px;">
                   <tbody>
                   <tr>
                       <th style="text-align:left;">GL Code:</th>
                       <th style="text-align:left;">Fund Name:</th>
                       <th style="text-align:right;">Fund Debit</th>
                       <th style="text-align:right;">Fund Credit</th>
                   </tr>
                   <tr>
                       <td style="text-align:left;">{{depositaccountglcode}}</td>
                       <td style="text-align:left;">{{depositaccountname}}</td>
                   `
           if(batch.Total > 0 ){
               htmlbodyFundActivity += `<td style="text-align:right;">$${batch.Total.toFixed(2)}</td>
                                        <td style="text-align:right;"></td>
                                       `
           }
           else {
               htmlbodyFundActivity += `<td></td>
               <td style="text-align:right;">$${batch.Total.toFixed(2)}</td>`
           }

           htmlbodyFundActivity += ''</tr>''
   
   for(let account of fundData) {
       htmlbodyFundActivity += `
           <tr>
               <td style="text-align:left;">${account.GlCode}</td>
               <td style="text-align:left;">${account.Name}</td>
       `
       
       if(account.Total < 0) {
           
           htmlbodyFundActivity +=`<td style="text-align:right;">$${account.Total.toFixed(2)}</td>
                                   <td style="text-align:right;"></td>
                                   `
       }
       else {
           htmlbodyFundActivity +=`
                                   <td style="text-align:right;"></td>
                                   <td style="text-align:right;">$${account.Total.toFixed(2)}</td>
                                   `
       }
       htmlbodyFundActivity += ''</tr>''
   }

   htmlbodyFundActivity += ''</tbody></table></div>''
   
   htmlbodyFundActivity += CreateTransactionPanel(batch)
   
   htmlbodyFundActivity += `</div></div></div>
   `

   
   return htmlbodyFundActivity
   
}



getTransactions(url)



function convertDate(date){
   var d = new Date(date.replace(
          /^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/,
          ''$4:$5:$6 $2/$3/$1''
          ));
    var d = d.setHours(d.getHours() + calculateOffset());
    var d = new Date(d);
   
      return d
}


function calculateOffset(){
   var basetime = ''0001-01-01T24:00:00.000Z'';
  
   var ticks = 792000000000; // change back to lava {{offset}}
   var epochTicks = 621355968000000000;
   var ticksPerMillisecond = 10000; // whoa!
   var maxDateMilliseconds = 8640000000000000;
   
   var ticksSinceEpoch = ticks - epochTicks;
   var millisecondsSinceEpoch = ticksSinceEpoch / ticksPerMillisecond;
   var offsetdate = new Date(millisecondsSinceEpoch).toISOString();
   
   
   
   basetime = new Date(basetime);
   offsetdate = new Date(offsetdate);
   
   var timeDiff = offsetdate.getTime() - basetime.getTime();
     var diffDays = Math.ceil(timeDiff / 1000 / 60 / 60); 
   
   
   return diffDays
}


function getFormattedDate(date) {
   var year = date.getFullYear();
 
   var month = (1 + date.getMonth()).toString();
   month = month.length > 1 ? month : ''0'' + month;
   
   var day = date.getDate().toString();
   day = day.length > 1 ? day : ''0'' + day;
   
   return month + ''/'' + day + ''/'' + year;
}

function createTransactionListString (array) {
       let arraylist = `''` + array.join(`,`) + `''`
   return arraylist  


   
}

function getFundActivity(accounts) {
   
   let accountlist  = []

   const sortedAccounts = accounts.sort(compareName)
   
   
   function compareName(a,b){
       return ('''' + a.Name).localeCompare(b.Name);
   }

   sortedAccounts.forEach((x) =>{

       const isInArray = sortedAccounts.includes(x.Name);
       
       if(accountlist.indexOf(x.Name) == -1) {
           accountlist.push(x.Name)
       }
   })

   

   let accountdata = [];
   accountlist.forEach(function(el){
       let accountobject = {}
       let accountx = accounts.filter(account => account.Name === el);
       accountobject.Name = accountx[0].Name
       accountobject.GlCode = accountx[0].GlCode
       let accountTotal = accountx.reduce(function(a,b){
           return a + b.Amount
       },0)

       accountobject.Total = accountTotal
       
       accountdata.push(accountobject)
   })
   
   return accountdata
}

function CreateTransactionPanel(batch){

   htmltransactionpane = `<div id="transactions-${batch.batchid}" class="tab-pane fade in">`

   for(let transaction of batch.transactions) {
       htmltransactionpane += createTransactionTable(transaction)
   }


   htmltransactionpane += ''</div>''
   return htmltransactionpane




}


//Creates Transaction Table
function createTransactionTable(transaction){

       let tabletemplate = `
                           <table class="table table-striped table-hover">
                               <thead>
                                   <tr>
                                       <th style="width: 10%; padding-right: 20px;">Data Source:</th>
                                       <th style="width: 15%; padding-right: 20px;">Transaction Code:</th>
                                       <th style="width: 15%; padding-right: 20px;">Name:</th>
                                       <th style="width: 15%; padding-right: 20px;">Email:</th>
                                       <th style="width: 10%; padding-right: 20px;">TransactionTotal:</th>
                                       <th style="width: 25%; padding-right: 20px;">Transaction Breakdown</th>
                                       <th style="width: 10%; padding-right: 20px;">Transaction Type:</th>
                                       <th>Reconciled On:</th>
                                   </tr>
                               </thead>
                               <tbody>
                                   <tr>
                                       <td style="padding-right: 20px;">Transnational</td>
                                       <td style="padding-right: 20px;">${transaction.transactionid}</td>
                                       <td style="padding-right: 20px;">${transaction.Name}</td>
                                       <td style="padding-right: 20px;">${transaction.email}</td>
                                       <td style="padding-right: 20px;">$${transaction.amount}</td>
                                       <td style="padding-right: 20px;"></td>
                                       <td>${transaction.transaction_type}</td>
                                       <td></td>
                                   </tr>
                                   <tr>
                                       <td style="padding-right: 20px; padding-bottom:20px;">Rock</td>

                                       <td style="padding-right: 20px;"><a href="/Transaction/${transaction.RockData[0].TransactionId}" target="_blank">${transaction.transactionid}</a></td>
                                       <td style="padding-right: 20px;">${transaction.RockData[0].Name}</td>
                                       <td style="padding-right: 20px;">${transaction.RockData[0].Email}</td>
                                       <td style="padding-right: 20px;">$${transaction.RockData[0].Total.toFixed(2)}</td>
                                       <td style="padding-right: 20px; vertical-align:top">
                                       <ul style="text-align:left">
                                       ${ transaction.RockData[0].Accounts.map(function(e){
                                               return `<li style="text-align:left">${e.Name}: $${e.Amount.toFixed(2)}</li>`
                                           }) }
                                       </ul>
                                       </td>
                                       <td>${transaction.RockData[0].TransactionType}</td>
                                       <td style="text-align:center;" id="${transaction.RockData[0].TransactionId}">
                                       ${transaction.RockData[0].Reconciled}
                                       </td>
                                   </tr>
                               </tbody>
                           </table>
                       `
       return tabletemplate
}

function checkReconciledCount(reconciledcount, batchcount){
               if(reconciledcount == batchcount) {
                       return true
                   }
}





function finalizedeposit(transactioncodes, batchid) {
  
   let codeTransformed = transactioncodes.split('','')
   
   codeTransformed.map((x) => {
     
      
       updateAttribute(x, batchid)
       
   })
   
   }
   
 function onCheck(batchid){
    let id = "''"+batchid+"-print''"
    
    let check = document.getElementById(batchid+"-print").checked
    
    console.log(check)
    
    if(check) {
            //checked
            document.getElementById(batchid).classList.remove("hidden-print")
            
        
            

        } else {
            //unchecked
            document.getElementById(batchid).classList.add("hidden-print")
        }
    
 }
   

</script>'

--Insert Shortcode
Insert Into LavaShortCode
([Name],[Description],[Documentation],[IsSystem],[IsActive],[TagName],[Markup],[TagType],[EnabledLavaCommands],[Parameters], [Guid])
Values
('Transnational Batches','This will list the transnational batches for the number of days back in the paramter.  The default is 15 days.',@Documentation,0,1,'batchlist',@markup,1,'','daysback^15|depositaccountname^Deposit Account|depositaccountglcode^',@ShortCodeGuid)


-- Insert Lava Webhook.

-- Get Defined Type Id
Declare @DefinedType Int = (Select Id From DefinedType Where [Guid] = '7bcf6434-8b15-49c3-8ef3-bab9a63b545d')

-- Set Attribute Ids of Webhook Defined Type
Declare @Method Int = (Select Id From Attribute where Guid in ('d9c92cdb-70ab-4d99-b580-eb55ed9fbee0'))
Declare @Template Int = (Select Id From Attribute where Guid in ('4303ae08-2208-4f46-9b98-fd91a710ce1e'))
Declare @LavaCommands Int =(Select Id From Attribute where Guid in ('2df9f53d-926e-4d2a-b755-818edd933781'))
Declare @Response Int = (Select Id From Attribute where Guid in ('73774e76-028f-445c-a078-bfb8885a102c'))
Declare @TemplateValue VARCHAR(MAX) = '{% assign daysbackint = daysback | Times: -1 %}

{% assign test = 0 %}
{% assign groupcheck = personguid | PersonByGuid | Group:''18'',''All'' | Size%}
{% assign groupcheck2 = personguid | PersonByGuid | Group:''18'',''All'' | Size%}
{% assign groupcheck3 = personguid | PersonByGuid | Group:''2'',''All'' | Size%}
{% assign test = test | Plus: groupcheck | Plus: groupcheck2 | groupcheck3 %}
{% assign CurrentPerson = personguid | PersonByGuid %}
{% if test > 0 %}



{% financialgateway Id:''3''%}
{% for gateway in financialgatewayItems %}
{% assign username = gateway | Attribute:''AdminUsername'' %}
{% assign password =gateway | Attribute:''AdminPassword'',''RawValue'' %}
{% endfor %}
{% endfinancialgateway %}
{% webrequest url:''https://secure.networkmerchants.com/api/query.php?username={{-username-}}&password={{password}}&start_date={{''Now'' | DateAdd:daysbackint,''d'' | Date:''yyyyMMdd00000''}}&end_date={{''Now'' | DateAdd:1,''d'' | Date:''yyyyMMdd235959''}}'' method:''POST'' responsecontenttype:''XML'' %}
    {% assign transactions = results.nm_response.transaction %}
{% endwebrequest %}


{% capture transactionlist %} 
  [ 
    {%- for transaction in transactions -%}
      {%- assign action = transaction.action -%}

      {%- capture actions -%}
        {{transaction.action | ToJSON }}
      {%- endcapture -%}

      {%- assign type = actions | Trim | Slice: 0, 1 -%}

      {% if type == ''{'' %}
        {%- capture transactionitem -%}
          { 
            "transaction_type": "{{transaction.transaction_type}}",
            "email":"{{transaction.email}}",
            "date":"{{action.date}}",
            "batchid":"{{action.processor_batch_id}}",
            "transactionid":"{{transaction.transaction_id}}",
            "actiontype":"{{action.action_type}}",
            "amount":"{{action.amount}}",
            "Name":"{{transaction.first_name}} {{transaction.last_name}}",
                        "RockData":[
                {% capture rockdata %}
                {% financialtransaction Where:''TransactionCode == {{transaction.transaction_id}}''%}
                    {% for item in financialtransactionItems %}
                   
                        {
                            {% assign person = item.AuthorizedPersonAliasId | PersonByAliasId %}
                            "Name":"{{person.FullName}}",
                            "Email":"{{person.Email}}",
                            "BatchId":"{{item.BatchId}}",
                            "TransactionId":{{item.Id}},
                            "SettlementDate":"{{item | Attribute:''SettlementDate''}}",
                            "SettlementBatch":"{{item | Attribute:''SettlementBatch''}}",
                            {% assign reconciled = item | Attribute:''ReconciledOn'' %}
                            {% if reconciled and reconciled != ''''  %}
                            "Reconciled":"{{item | Attribute:''ReconciledOn''}}",
                            {% else %}
                            "Reconciled": null,
                            {% endif %}
                            "TransactionCode":"{{item.TransactionCode}}",
                            "TransactionType":"{{item.FinancialPaymentDetail.CurrencyTypeValue.Value}}",
                            "Accounts":[
                            {% assign total = 0 %}
                            {% capture accountdata %}
                                    {% for account in item.TransactionDetails %}
                                        {
                                                
                                           "Name":"{{account.Account.Name}}",
                                           "Amount":{{account.Amount}},
                                           "GlCode":"{{account.Account.GlCode}}"
                                           {% assign total = total | Plus: account.Amount %}
                                        },                                        
                                    {% endfor %}
                            {% endcapture %}
                            {{accountdata | ReplaceLast:'','',''''}}
                                

                                ],
                            "Total":{{ total | AsDecimal}}
                            },
                    {% endfor %}
                {% endfinancialtransaction %}
                {% endcapture %}
                {{rockdata | ReplaceLast:'','',''''}}
                ]
          }
        {%- endcapture -%}
        {{transactionitem | Trim}}, 
      {%- elseif type == ''['' -%}

        {%- assign actionarraysize = action | Size -%}
        {%- assign actionarraysize = actionarraysize | Minus:1-%}
        {%- for i in (0..actionarraysize) -%}
          {%- capture transactionitem -%}
          {
            "transaction_type": "{{transaction.transaction_type}}",
            "email":"{{transaction.email}}",
            "batchid":"{{action[i].processor_batch_id}}",
            "date":"{{action[i].date}}",
            "transactionid":"{{transaction.transaction_id}}",
            "actiontype":"{{action[i].action_type}}",
            "amount":"{{action[i].amount}}",
            "Name":"{{transaction.first_name}} {{transaction.last_name}}",
                        "RockData":[
                {% capture rockdata %}
                {% financialtransaction Where:''TransactionCode == {{transaction.transaction_id}}''%}
                    {% for item in financialtransactionItems %}
                   
                        {
                            {% assign person = item.AuthorizedPersonAliasId | PersonByAliasId %}
                            "Name":"{{person.FullName}}",
                            "Email":"{{person.Email}}",
                            "BatchId":"{{item.BatchId}}",
                            "TransactionCode":"{{item.TransactionCode}}",
                            "TransactionId":{{item.Id}},
                            "SettlementDate":"{{item | Attribute:''SettlementDate''}}",
                            "SettlementBatch":"{{item | Attribute:''SettlementBatch''}}",
                            "Reconciled":"{{item | Attribute:''ReconciledOn''}}",
                            "TransactionType":"{{item.FinancialPaymentDetail.CurrencyTypeValue.Value}}",
                            "Accounts":[
                            {% assign total = 0 %}
                            {% capture accountdata %}
                                    {% for account in item.TransactionDetails %}
                                        {
                                                
                                           "Name":"{{account.Account.Name}}",
                                           "Amount":{{account.Amount}},
                                           "GlCode":"{{account.Account.GlCode}}"
                                           {% assign total = total | Plus: account.Amount %}
                                        },                                        
                                    {% endfor %}
                            {% endcapture %}
                            {{accountdata | ReplaceLast:'','',''''}}
                                

                                ],
                            "Total":{{ total | AsDecimal}}
                            },
                    {% endfor %}
                {% endfinancialtransaction %}
                {% endcapture %}
                {{rockdata | ReplaceLast:'','',''''}}
                ]
          }
          {%- endcapture -%}
          {{transactionitem | Trim}},
        {% endfor %}
      {% endif %}
    {% endfor %} 
    ] 
  {%endcapture%}
  {% assign transactions = transactionlist | ReplaceLast:'','','''' | FromJSON%}

  {% capture transactionoutput %}
      {% for transaction in transactions %}
        {% if transaction.batchid and transaction.batchid != empty%}
            {{transaction | ToJSON}},
        {% endif %}
      {% endfor %}
  {% endcapture %}
  
[{{transactionoutput  | ReplaceLast:'','','''' | Replace:'',,'','',''}}]
{% endif %}
'

-- Insert Defined Value and Save Id
Insert Into DefinedValue
([IsSystem],[DefinedTypeId], [Value], [Description], [Guid], [IsActive],[Order])
VALUES
(0,@DefinedType,'/nmiplugin/nmitransactionmatch/{personguid}/{daysback}','This endpoint is used to generate transaction data used for matching transnational transactions to Rock Transactions.',NewId(),1,0)

Declare @DefinedValue Int = Scope_Identity()



-- Insert Attribute Values
Insert Into AttributeValue
([IsSystem],[AttributeId],[EntityId],[Value],[Guid])
VALUES
(0,@Response,@DefinedValue,'application/json',NewId()),
(0,@LavaCommands,@DefinedValue,'RockEntity,WebRequest',NewId()),
(0,@Template,@DefinedValue,@TemplateValue,NewId()),
(0,@Method,@DefinedValue,'GET',NewId())


-- Create Page for Displaying Batches


Declare @ParentId Int = (Select [Id] From Page Where [Guid] = '8c586b41-5861-46c3-91df-d2f2c2e5046c')

Declare @HTMLCONTENTCONTENT Varchar(max) = '{[ batchlist daysback:''21'' depositaccountname:''Deposit Account'' depositaccountglcode:'''']}'


Insert Into Page 
([InternalName],[ParentPageId],[PageTitle],[IsSystem],[LayoutId],[RequiresEncryption],[EnableViewState],[PageDisplayTitle],[PageDisplayBreadCrumb],[PageDisplayIcon],[PageDisplayDescription],[DisplayInNavWhen],[MenuDisplayDescription],[MenuDisplayIcon],[MenuDisplayChildPages],[BreadCrumbDisplayName],[BreadCrumbDisplayIcon],[Order],[OutputCacheDuration],[IncludeAdminFooter],[Guid],[BrowserTitle],[CreatedDateTime],[ModifiedDateTime],[AllowIndexing])
VALUES 
('Transnational Batches',@ParentId,'Transnational Batches',0,12,0,1,1,1,1,1,0,0,0,1,1,0,0,0,1,@PAGEGUID,'Transnational Batches',GETDATE(),GETDATE(),0)

Declare @PageId Int = Scope_Identity()


--Create HTML Block

Insert Into Block 
([IsSystem],[PageId],[BlockTypeId],[Zone],[Order],[Name],[OutputCacheDuration],[Guid],[CreatedDateTime],[ModifiedDateTime])
VALUES 
(0,@PageId,6,'Main',0,'Transnational Batches',0,@BlockGuid,GetDate(),GetDate())

declare @newblock as Int = (Select SCOPE_IDENTITY())

-- Create HTML Content
Insert Into HTMLContent 
([BlockId],[Version],[Content],[IsApproved],[ApprovedDateTime],[Guid],[CreatedDateTime],[ModifiedDateTime])
VALUES 
(@newblock,1,@HTMLCONTENTCONTENT,1,GetDate(),@HTMLContent,GetDate(),GetDate())
