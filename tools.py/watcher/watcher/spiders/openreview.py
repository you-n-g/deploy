import scrapy
# scrapy crawl iclr24
from watcher.items import OpenReviewPaper


class PaperSpider(scrapy.Spider):
    name = "iclr24"
    # URL_TPL = "https://openreview.net/search?content=keywords&group=ICLR.cc&page=1&source=forum&term={}"
    DOMAIN = "ICLR.cc"
    content_venue = "ICLR 2024 Conference Submission"

    def start_requests(self):
        for kw in ["Agent", "Agents", "Language+Agent", "tool", "LLM", "large+language+model", "grounding"]:
            yield scrapy.Request(url=self.get_url(kw), callback=self.parse_list)

    def get_forum_url(self, forum):
        return f"https://api2.openreview.net/notes?details=replyCount%2Cwritable%2Csignatures%2Cinvitation%2Cpresentation&domain={self.DOMAIN}%2F2024%2FConference&forum={forum}&limit=1000&trash=true"

    def get_url(self, term):
         return f"https://api2.openreview.net/notes/search?content=keywords&group={self.DOMAIN}&limit=1000&source=forum&term={term}&type=terms"

    def parse_list(self, response):
        # automatically get next page
        # scrapy shell -s ROBOTSTXT_OBEY=False https://api2.openreview.net/notes/search?content=keywords&group=ICLR.cc&limit=1000&source=forum&term=Agent&type=terms
        res = response.json()
        for note in res["notes"]:
            if note["content"]["venue"]["value"].startswith(self.content_venue):
                request =response.follow(self.get_forum_url(note["forum"]), callback=self.parse_inner_page) 
                request.meta['item'] = note
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
            'rating': rates,
            'source': self.name,
        }
        yield OpenReviewPaper(**data)


class NIPSSpider(PaperSpider):
    name = "nips23"
    content_venue = "NeurIPS 2023"
    DOMAIN = "NeurIPS.cc"
    def parse_list(self, response):
        res = response.json()
        for note in res["notes"]:
            if note["content"]["venue"]["value"].startswith(self.content_venue):
                data = {
                    'id': note['id'],
                    'title': note['content']['title']['value'],
                    'abstract': note['content']['abstract']['value'],
                    'keywords': note['content']['keywords']['value'],
                    'source': self.name,
                }
                yield OpenReviewPaper(**data)
