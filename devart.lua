require("oauth")
require("stream")
require("process");
require("dataparser");
require("strutil");
require("terminal");
require("net");
require("time")


DA_CLIENTID="8350"
DA_CLIENTSECRET="a73eb3b0c0053527b9a2695133b20fe3"


-- Instead of putting Username and Credentials into this script, you can put them in environment variables
tmpstr=process.getenv("DA_CLIENTID")
if strutil.strlen(tmpstr) > 0 then DA_CLIENTID=tmpstr end
tmpstr=process.getenv("DA_CLIENTSECRET")
if strutil.strlen(tmpstr) > 0 then DA_CLIENTSECRET=tmpstr end


report_type=""
ShowHtml=true
ShowNoteThread=false

fave_color="~m~e"
comment_color="~b~e"
reply_color="~r"


function FormatTimestamp(ts)
local secs, when="error"
local day=3600 * 24

secs=time.tosecs("%Y-%m-%dT%H:%M:%S", ts)
-- if secs is zero, it means we got an item that's not a notification
if secs > 0
	then
	if (time.secs() - secs) < day then when="~e"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
	elseif (time.secs() - secs) < day * 2 then when="~y"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
	else when="~c"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0" 
	end
end

if when==nil then when="error" end
return(when)
end



function OAuthGet(OA)

OA:set("redirect_uri","http://localhost:8989/deviantart.callback");
OA:stage1("https://www.deviantart.com/oauth2/authorize");

Out:puts("GOTO: ".. OA:auth_url().."\n");

OA:listen(8989, "https://www.deviantart.com/oauth2/token");

OA:finalize("https://www.deviantart.com/oauth2/token");
OA:save("");
end



function DAGet(url)
local S, reply

S=stream.STREAM(url, "r oauth='" .. OA:name() .. "'");
if S ~= nil
then
reply=S:getvalue("HTTP:ResponseCode")

if reply=="401" 
then 
OAuthGet(OA)
S=stream.STREAM(url, "r oauth='" .. OA:name() .. "'")
end

doc=S:readdoc()
S:close()
else
Out:puts("~rERROR: Failed to connect\n")
end

return doc
end



function PrintItems(P)
n=P:first();
while n ~= nil
do
Out:puts("> "..n.."\n")
n=P:next();
end

end



function GalleryLoadItem(cursor)
local stats
local Item={}

Item.id=cursor:value("deviationid")
Item.url=strutil.unQuote(cursor:value("url"))
Item.title=cursor:value("title")
Item.published_time=tonumber(cursor:value("published_time"))
stats=cursor:open("stats")
if stats ~= nil then 
Item.faves=tonumber(stats:value("favourites"))
Item.comments=tonumber(stats:value("comments"))
else 
Item.faves=0
Item.comments=0
end

return Item
end




function GallerySortFunc(i1, i2)

if report_type == "faves" 
then
 if i1.faves < i2.faves then return true end
elseif report_type == "comments" 
then 
 if i1.comments < i2.comments then return true end
else
if i1.published_time < i2.published_time then return true end
end
return false
end



function GalleryLoad(OA, offset, Items)
local doc, P, I, item, more;

more=0;
url="https://www.deviantart.com/api/v1/oauth2/gallery/all?limit=24&offset="..offset;
doc=DAGet(url)

P=dataparser.PARSER("json",doc);

if P:value("has_more") == "true" then more=P:value("next_offset") end

I=P:open("/results");
item=I:first();
while item ~= nil
do
table.insert(Items, GalleryLoadItem(item))
item=I:next();
end



return(tonumber(more));
end




function Gallery(OA)
local offset, i, item
local pages=1
local Items={}

offset=GalleryLoad(OA, 0, Items);
while offset > 0 
do
io.write("\rloading: "..#Items.." items, "..pages.." pages".."           ")
offset=GalleryLoad(OA, offset, Items);
pages=pages+1 
end

Out:puts("\n")
table.sort(Items, GallerySortFunc)

for i,item in ipairs(Items)
do
	if report_type == "gallery" 
	then 
		Out:puts(item.title .."  ".. item.url.."\n");
		Out:puts("faves: "..item.faves.." comments: "..item.comments.."\n");
		Out:puts("\n")
	elseif report_type == "faves" then Out:puts(item.faves .. "  " .. item.title .."  ".. item.url.."\n");
	elseif report_type == "comments" then Out:puts(item.comments .. "  " .. item.title .."  ".. item.url.."\n");
	end
end


end


function DisplayComment(src)
Out:puts(src.."\n");
end



function NotificationsDisplay(Noti)
local Devs, item, str, ntype, secs, when, typestr;

when=FormatTimestamp(Noti:value("ts"))
ntype=Noti:value("type");
typestr=ntype;
if typestr=="favourite" then typestr=fave_color.."favorite~0"
elseif typestr=="comment_deviation" then typestr=comment_color.."comment~0 "; 
elseif typestr=="reply" then typestr=reply_color.."reply~0 "; 
end

str=when .. "   ".. typestr .. "  ~e" .. Noti:value("by_user/username").. "~0  ";
Devs=Noti:open("/deviations");
if Devs ~=nil
then
item=Devs:first()
while item ~=nil
do
str=str..Devs:value("title") .. "  ";
item=Devs:next()
end
end

Out:puts(str.."\n");

if ntype=="comment_deviation" or ntype=="comment_profile" or ntype=="reply"
then
	DisplayComment(Noti:value("comment/body"));
end

end



function NotificationsGet(OA, start_cursor)

local P, I, U, doc, url, cursor;

url="https://www.deviantart.com/api/v1/oauth2/feed/notifications";
if start_cursor ~= nil then url=url .. "?cursor=" .. start_cursor end;

doc=DAGet(url)
cursor=start_cursor;
P=dataparser.PARSER("json",doc);
if P ~= nil
then
I=P:open("/items")
if I ~= nil
then
	cursor=P:value("cursor");
	item=I:first();
	while item ~= nil
	do
		NotificationsDisplay(item)
		item=I:next();
	end
end
end

return(cursor);
end


function Notifications(OA, qty)
local cursor=nil;
local count=0;

for i=1,100,1
do
cursor=NotificationsGet(OA, cursor);
process.sleep(1);
count=count+1;
if count > qty then break end;
end

end



function NotesFormatBody(body)
local Tokens;
local str, html;
local output="";

Tokens=strutil.TOKENIZER(body, "<|>", "ms");
str=Tokens:next()
while str ~= nil
do

if str== '----------'
then
	if ShowNoteThreads ~= true then break end
end

if str == '<'
then
	html="";
	while str ~= nil and str ~= '>'
	do
		html=html .. str;
		str=Tokens:next();
	end
	output=output.." ";

	if ShowHtml == true
	then
		if html=="<br /" then output=output.."\n" end
		if html=="<i " then output=output.."*" end
		if html=="</i " then output=output.."*" end
		if html=="<b " then output=output.."*" end
		if html=="</b " then output=output.."*" end
		if string.sub(html, 1, 8) == "<a href="
		then
			output=output..string.sub(html,9).." ";
		end
	end
--	print("html: ["..html.."] ");
else
	output=output..str;
end

str=Tokens:next()
end

return(output);
end


function NotesGet(OA, qty, offset)
local P, I, U, doc, url, when;
local count=0;

url="https://www.deviantart.com/api/v1/oauth2/notes?limit="..qty;
if offset ~= nil and tonumber(offset) > 0
then
url=url.."&offset="..offset
end

doc=DAGet(url)
P=dataparser.PARSER("json",doc);
I=P:open("/results");
if I ~= nil
then
	item=I:first();
	while item ~= nil
	do
		when=FormatTimestamp(item:value("ts"))
		Out:puts("****  ".. when .. "~0  ~e" .. item:value("user/username") .. "~0   " .. item:value("subject").."\n");
		doc=NotesFormatBody(strutil.unQuote(item:value("body")));
		Out:puts("   " .. doc .."\n\n");

		count=count+1;
		item=I:next();
	end
end

return count
end



function Notes(OA, qty)
local count=0
local i

while count < qty
do
count=count + NotesGet(OA, qty, count);
process.sleep(1);
end

end



function PrintUsage()

print("usage:")
print("	lua devart.lua notify [no of pages]              display user notifications")
print("	lua devart.lua faves                             display favorities per deviation")
print("	lua devart.lua comments                          display comments per deviation")
print("	lua devart.lua notes                             display notes sent to the user")

end



-- MAIN STARTS HERE

--[[ Proxy settings. 

Get these from any of these different environment variables
Proxy must have the form <protocol>:<host>:<port> or <protocol>:<user>:<password>@<host>:<port>

e.g.

socks4://localhost:4040
socks5://user:password@socksproxy:1080
https://openproxy.com:8080
sshtunnel:login:pass@cloudhost

]]--

Proxy=""

if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("SOCKS_PROXY") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("socks_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("HTTPS_PROXY") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("https_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("all_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("devart_proxy") end

if strutil.strlen(Proxy) ==0 then net.setProxy(Proxy) end

-- proxy settings can also be set by adding a line here like:
-- net.setProxy("https://myproxy:1080")
-- net.setProxy("sshtunnel:mysshserver")

--uncomment this for debugging
--process.lu_set("HTTP:Debug","y");

process.lu_set("HTTP:UserAgent","devart.lua");

qty=0;
Out=terminal.TERM()

OA=oauth.OAUTH("auth","deviantart",DA_CLIENTID, DA_CLIENTSECRET,"browse feed note", "https://www.deviantart.com/oauth2/token");
if OA:load("deviantart") == 0 then OAuthGet(OA) end


report_type=arg[1]
if arg[2] ~= nil then qty=tonumber(arg[2]) end

if arg[1] == "notify" then Notifications(OA, qty);
elseif arg[1] == "faves" or arg[1]== "comments" then Gallery(OA)
elseif arg[1] == "notes" then Notes(OA, qty);
else PrintUsage()
end

Out:reset();
