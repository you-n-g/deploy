import scrapy
from functools import partial
from watcher.items import OpenReviewPaper
from urllib.parse import urlencode


class PaperSpider(scrapy.Spider):
    name = "iclr24"
    # URL_TPL = "https://openreview.net/search?content=keywords&group=ICLR.cc&page=1&source=forum&term={}"
    DOMAIN = "ICLR.cc"  #  需要看一下 paper list 里面的 group字段
    content_venue = "ICLR 2024 Conference Submission"

    def start_requests(self):
        # 大小写不敏感
        # Agent & Agents 不一样 ...
        for kw in [
                "Agent", "Agents", "Language+Agent", "Communicative Agents", "tool", "LLM", "large+language+model",
                "grounding"
        ]:
            yield scrapy.Request(url=self.get_url(kw), callback=self.parse_list)
        # 组合的时候别漏了：Agent +  Language(不一定要large)

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
                request = response.follow(self.get_forum_url(note["forum"]), callback=self.parse_inner_page)
                request.meta['item'] = note
                yield request

    RATE_KEY_L = ["rating"]

    def get_rates(self, response):
        res = response.json()
        rates = []
        for com in res["notes"]:
            for k in self.RATE_KEY_L:
                if k not in com["content"]:
                    continue
                rate = int(com["content"][k]["value"].split(":")[0])
                rates.append(rate)
        return rates

    def parse_inner_page(self, response):
        # https://api2.openreview.net/notes?details=replyCount%2Cwritable%2Csignatures%2Cinvitation%2Cpresentation&domain=ICLR.cc%2F2024%2FConference&forum=PhJUd3mbhP&limit=1000&trash=true
        item = response.meta['item']

        rates = self.get_rates(response)

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


class EMNLP(PaperSpider):
    name = "emnlp"
    content_venue = "EMNLP 2023"
    DOMAIN = "EMNLP"
    RATE_KEY_L = ['Soundness', 'Excitement']


# It does not work due to the rate is hidden
# class NIPSSpider24(NIPSSpider):
#     name = "nips24"
#     content_venue = "NeurIPS 2024"


def get_conf_uri(conf, year, venue, limit=1000, offset=0):
    """
    Generate the URL for fetching accepted papers from OpenReview based on the given parameters.

    Parameters:
    - conf: The conference acronym (e.g., "ICML").
    - year: The year of the conference (e.g., "2024").
    - venue: The specific venue type (e.g., "Oral", "Poster", "Spotlight").
    - limit: The number of results to return (default is 1000).
    - offset: The offset for pagination (default is 0).

    Returns:
    - A formatted URL string.
    """
    base_url = "https://api2.openreview.net/notes"
    details = "replyCount,presentation"
    domain = f"{conf}.cc/{year}/Conference"
    invitation = f"{conf}.cc/{year}/Conference/-/Submission"
    content_venue = f"{conf} {year} {venue}"

    # Create a dictionary of query parameters
    query_params = {
        "content.venue": content_venue,
        "details": details,
        "domain": domain,
        "invitation": invitation,
        "limit": limit,
        "offset": offset
    }

    # Use urlencode to escape the query parameters
    query_string = urlencode(query_params)

    return f"{base_url}?{query_string}"


class OpenReviewFullSpider(scrapy.Spider):
    name = "icml24"
    get_list_uri = partial(get_conf_uri, "ICML", "2024")

    def start_requests(self, limit=50, offset=0):
        """
        We start from these pages
        """
        venue_l = ["Oral", "Poster", "Spotlight"]
        for venue in venue_l:
            uri = self.get_list_uri(venue=venue, limit=limit, offset=offset)
            yield scrapy.Request(url=uri,
                                 callback=self.parse_list,
                                 cb_kwargs={
                                     "venue": venue,
                                     "limit": limit,
                                     "offset": offset
                                 })

    def parse_list(self, response, venue, limit, offset):
        """
        Read the content in the page and automatically navigate through pages.
        """
        res = response.json()

        # Paging...
        if res["count"] > limit + offset:
            request = response.follow(self.get_list_uri(venue=venue, limit=limit, offset=limit + offset),
                                      callback=self.parse_list,
                                      cb_kwargs={
                                          "venue": venue,
                                          "limit": limit,
                                          "offset": limit + offset
                                      })
            request.meta['venue'] = venue
            yield request

        # Parse list content
        notes = res.get("notes", [])
        for note in notes:
            data = {
                'id': note['id'],
                'title': note['content']['title']['value'],
                'abstract': note['content']['abstract']['value'],
                # 'keywords': note['content']['keywords']['value'],
                'source': self.name,
                "venue": venue,
            }
            yield OpenReviewPaper(**data)
