require("oauth")
require("stream")
require("process");
require("dataparser");
require("strutil");
require("net");

DA_CLIENTID="8350"
DA_CLIENTSECRET="a73eb3b0c0053527b9a2695133b20fe3"
report_type=""


function OAuthGet(OA)

OA:set("redirect_uri","http://localhost:8989/deviantart.callback");
OA:stage1("https://www.deviantart.com/oauth2/authorize");

print("GOTO: ".. OA:auth_url());

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
print("ERROR: Failed to connect")
end

return doc
end



function PrintItems(P)
n=P:next();
while n ~= nil
do
print("> "..n)
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
item=I:next();
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

print()
table.sort(Items, GallerySortFunc)

for i,item in ipairs(Items)
do
	if report_type == "gallery" 
	then 
		print(item.title .."  ".. item.url);
		print("faves: "..item.faves.." comments: "..item.comments);
		print("")
	elseif report_type == "faves" then print(item.faves .. "  " .. item.title .."  ".. item.url);
	elseif report_type == "comments" then print(item.comments .. "  " .. item.title .."  ".. item.url);
	end
end


end


function DisplayComment(src)
print(src);
end



function NotificationsDisplay(Noti)
local Devs, str, ntype;

ntype=Noti:value("type");
str=Noti:value("ts") .. "   ".. ntype .. "  " .. Noti:value("by_user/username").. "  ";
Devs=Noti:open("/deviations");
if Devs ~=nil
then
while Devs:next()
do
str=str..Devs:value("title") .. "  ";
end
end

print(str);

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
	item=I:next();
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


function Notes(OA)
local P, I, U, doc, url, cursor;

url="https://www.deviantart.com/api/v1/oauth2/notes";

doc=DAGet(url)
P=dataparser.PARSER("json",doc);
I=P:open("/results");
if I ~= nil
then
	cursor=P:value("cursor");
	item=I:next();
	while item ~= nil
	do
		print(item:value("ts") .. "  " .. item:value("user/username") .. "   " .. item:value("subject"));
		print("   "..item:value("body"));
		print("");

		item=I:next();
	end
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

Proxy=""

if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("SOCKS_PROXY") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("socks_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("HTTPS_PROXY") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("https_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("all_proxy") end
if strutil.strlen(Proxy) == 0 then Proxy=process.getenv("devart_proxy") end


-- you can set a proxy here
if strutil.strlen(Proxy) ==0 then net.setProxy(Proxy) end

--uncomment this for debugging
--process.lu_set("HTTP:Debug","y");


process.lu_set("HTTP:UserAgent","devart.lua");

qty=0;


OA=oauth.OAUTH("auth","deviantart",DA_CLIENTID, DA_CLIENTSECRET,"browse feed note", "https://www.deviantart.com/oauth2/token");
if OA:load("deviantart") == 0 then OAuthGet(OA) end


report_type=arg[1]
if arg[2] ~= nil then qty=tonumber(arg[2]) end

if arg[1] == "notify" then Notifications(OA, qty);
elseif arg[1] == "faves" or arg[1]== "comments" then Gallery(OA)
elseif arg[1] == "notes" then Notes(OA);
else PrintUsage()
end


