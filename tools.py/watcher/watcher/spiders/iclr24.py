import scrapy
# scrapy crawl iclr24
from watcher.items import OpenReviewPaper


class PaperSpider(scrapy.Spider):
    name = "iclr24"
    # URL_TPL = "https://openreview.net/search?content=keywords&group=ICLR.cc&page=1&source=forum&term={}"
    URL_TPL = "https://api2.openreview.net/notes/search?content=keywords&group=ICLR.cc&limit=1000&source=forum&term={}&type=terms"

    def start_requests(self):
        for kw in ["Agent", "Agents", "Language+Agent", "tool", "LLM", "large+language+model", "grounding"]:
            yield scrapy.Request(url=self.URL_TPL.format(kw), callback=self.parse_list)

    FORUM_URL_TPL = "https://api2.openreview.net/notes?details=replyCount%2Cwritable%2Csignatures%2Cinvitation%2Cpresentation&domain=ICLR.cc%2F2024%2FConference&forum={}&limit=1000&trash=true"
    def parse_list(self, response):
        # automatically get next page
        # scrapy shell -s ROBOTSTXT_OBEY=False https://api2.openreview.net/notes/search?content=keywords&group=ICLR.cc&limit=1000&source=forum&term=Agent&type=terms
        res = response.json()
        for note in res["notes"]:
            request =response.follow(self.FORUM_URL_TPL.format(note["forum"]), callback=self.parse_inner_page) 
            request.meta['item'] = note
            if note["content"]["venue"]["value"] == 'ICLR 2024 Conference Submission':
                yield request

    def parse_inner_page(self, response):
        # https://api2.openreview.net/notes?details=replyCount%2Cwritable%2Csignatures%2Cinvitation%2Cpresentation&domain=ICLR.cc%2F2024%2FConference&forum=PhJUd3mbhP&limit=1000&trash=true
        item = response.meta['item']
        res = response.json()
        rates = []
        for com in res["notes"]:
            if "rating" not in com["content"]:
                continue
            rate = int(com["content"]["rating"]["value"].split(":")[0])
            rates.append(rate)
        # create a json with id, title, abstract, keywords, rating
        data = {
            'id': item['id'],
            'title': item['content']['title']['value'],
            'abstract': item['content']['abstract']['value'],
            'keywords': item['content']['keywords']['value'],
            'rating': rates
        }
        yield OpenReviewPaper(**data)
