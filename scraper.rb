# encoding: utf-8

# Indeed.com

require 'open-uri'
require 'nokogiri'
require 'net/http'
require 'ostruct'
require 'mechanize'
 require 'sqlite3'
require 'sanitize'
require 'scraperwiki'


queries=[]
states=['Iowa',  'Minnesota',  'Nevada',  'Utah',  'Virginia', 'Washington'  ]
counts = Hash.new(0)
queryurl="http://www.indeed.com/jobs?"
ht = Hash.new {|h,k| h[k]=[]}
tt = Hash.new {|h,k| h[k]=[]}
gt = Hash.new {|h,k| h[k]=[]}
ct = Hash.new {|h,k| h[k]=[]}
st = Hash.new {|h,k| h[k]=[]}
et = Hash.new {|h,k| h[k]=[]}
geo = Hash.new {|h,k| h[k]=[]}

t='<script type="text/javascript"> function rclk('

for element in states
 helpurl=queryurl+"l="+element+"&sort=date"
  puts queryurl
    doc = Nokogiri::HTML(open(URI::encode(helpurl)))
  resultstotal=doc.search("div[@id='searchCount']").inner_html
  total = resultstotal.sub('Jobs 1 to 10 of','')
  total = total.gsub!(',','')
  total = Integer(total)
  puts total
  puts element
  resultsperpage = 10
  pages = (total / resultsperpage) + 1
  puts pages
  puts element
  resultslimit=1000
  url_state=element

  j=0
  checkAgainst = ['']
  c=0
  
  tt.clear
  ht.clear
  gt.clear
  ct.clear
  st.clear
  et.clear
  geo.clear
  
  

  while j<=resultslimit
    g=0        
             while c<=resultslimit
                long_url= "http://fullrss.net/a/http/rss.indeed.com/rss?q=&l=" + url_state + "&sort=date&start="+c.to_s()
                puts long_url
                scraping = Nokogiri::XML(open(long_url))
                c=c+resultsperpage
                puts c
                scraping.css("item").each do |result|
                  identification=result.css('link').inner_html
                  identification.to_s()
                  identification=identification.split("-").last
                  puts identification
                  text=result.css("description").inner_html
                  timing=result.css("pubDate").inner_html
                  
                  begin
                    long_content=result.css("content:encoded").inner_html
                  rescue
                  end
                  begin
                
                    some_id=result.css("guid").inner_html
                  rescue
                  end
                  begin
                    map=result.css("georss:point").inner_html
                    employer=result.css("source").inner_html          
                  rescue
                  end
   

  
                  text=Sanitize.clean(text)
                  text.gsub!(/&lt.*?&gt;/im, "")
                  text.gsub!(/\[/im, "")


                  begin
                   ht[identification]<< long_content
                  rescue
                  end
                  begin
                   ht[identification]<< text
                  rescue
                  end
                  tt[identification]<< timing
                  geo[identification]<< map
  
                end

             end

            
 

    pageurl = helpurl+"&start="+j.to_s()
    puts pageurl
    page = Nokogiri::HTML(open(URI::encode(pageurl)))
    use= page.search("body")
    use=use.to_s()
    myarray=use.scan(/jobmap\[.\]= {(.*?)}/m)
    
    while g<10
      myarray[g]=myarray[g].to_s()
      zip = $1 if myarray[g].scan(/zip:'(.*?)'/m)
      ids = $1 if myarray[g].scan(/jk:'(.*?)'/m)
      cmpid = $1 if myarray[g].scan(/cmpid:'(.*?)'/m)
      srcid = $1 if myarray[g].scan(/srcid:'(.*?)'/m)
      efccid = $1 if myarray[g].scan(/efccid: '(.*?)'/m)

      g=g+1
      if zip!='' && !gt.has_key?(ids) 
      gt[ids]<< zip
      end
      if cmpid!='' && !ct.has_key?(ids) 
      ct[ids]<< cmpid
      end
      if srcid!='' && !st.has_key?(ids) 
      st[ids]<< srcid
      end
      if efccid!='' && !et.has_key?(ids) 
      et[ids]<< efccid
      end
    end
 
    
   pageurl = helpurl+"&start="+j.to_s()
   page = Nokogiri::HTML(open(URI::encode(pageurl)))
   page.search("div[@itemtype='http://schema.org/JobPosting']").each do |node|

       if node.count > 0

          jobtitle=node.css("h2 a").inner_html
          jobtitle = Sanitize.clean(jobtitle)
          ident=node.css("h2")
          ident=ident.first['id']
          ident.to_s()
          ident.gsub!(/.*_/im, "") 

          employer=node.css("span[class=company] span").inner_html
          employer = Sanitize.clean(employer)
          location=node.css("span[itemprop=jobLocation] span span").inner_html
          jobdescription=node.css("table tr td div span").inner_html
          jobdescription = jobdescription.sub(/(.*)View more .*/,'/1')
          jobdescription = Sanitize.clean(jobdescription)
          salary=node.css("table tr td div nobr").inner_html
          date = node.css("table tr td span[class=date]").inner_html
          state=element
          time=Time.now
  
          data={
            "jobtitle" => jobtitle,
            "employer" => employer,
            "location" => location,
            "description" => jobdescription,
            "salary" => salary,
            "state" => state,
            "date" => date,
            "current_time" => time,
            "long_description"=>'',
            "long_timing"=>'',
            "id"=>ident,
            "zip"=>'',
            "srcid"=>'',
            "efccid"=>'',
            "cmpid"=>'',
            "geo"=>'',


           }
          
  
         

          if data["salary"]!=''
              if gt[ident]!=''
                data["zip"]=gt[ident]
                data["srcid"]=st[ident]
                data["cmpid"]=ct[ident]
                data["efccid"]= et[ident]
    
              end
              if ht.has_key?(ident)
                data["long_description"]=ht[ident]
                data["long_timing"]=tt[ident]
                data["geo"]=geo[ident]
                
              end

              
                  puts data["jobtitle"]
                  ScraperWiki.save_sqlite(['id'], data)
                  puts "success"

              
              

             
             end

           end
      end
   
     j=j + resultsperpage
  end
end
