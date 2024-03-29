# Learning..
# https://docs.scrapy.org/en/latest/intro/tutorial.html
import json
from pathlib import Path
import re

import scrapy

from watcher.items import Paper


class PaperSpider(scrapy.Spider):
    name = "paper"

    def start_requests(self):
        # arxive authors
        urls = [
            "https://arxiv.org/search/?searchtype=author&query=Narasimhan%2C+K&order=-announced_date_first&size=50&abstracts=show&start=0",
        ]
        for url in urls:
            yield scrapy.Request(url=url, callback=self.parse_arxiv)

        # https://github.com/WooooDyy/LLM-Agent-Paper-List/blob/main/README.md
        yield scrapy.Request(url="https://raw.githubusercontent.com/WooooDyy/LLM-Agent-Paper-List/main/README.md", callback=self.parse_github)

        yield scrapy.Request(url="https://api.semanticscholar.org/v1/paper/arXiv:2310.06770?include_unknown_references=true", callback=self.parse_arxiv_cite)

    def parse_arxiv(self, response):
        # page = response.url.split("/")[-2]
        # filename = f"quotes-{page}.html"
        # Path(filename).write_bytes(response.body)
        # self.log(f"Saved file {filename}")
        for e in response.css("li[class='arxiv-result']"):
            data = {
                "id": e.css("a").attrib['href'],
                "title": e.css("li > p[class*='title']").css("::text").extract_first().strip(),
                "abstract": e.css("span[class*='abstract-full']::text").extract_first().strip(),
                "source": response.url
            }
            p = Paper(**data)
            yield p

    def parse_arxiv_cite(self, response):
        json_obj = json.loads(response.text)
        for c in json_obj["citations"]:
            data = {
                "id": c["doi"],
                "title": c["title"],
                "abstract": "",
                "source": response.url
            }
            p = Paper(**data)
            yield p

    def parse_github(self, response):
        for p in re.findall(r"\*\*(?P<title>[^\*\n]+)\*\*.*?\[(?P<text>paper)\]\((?P<url>[^\)]+)\)", response.text):
            data = {
                "id": p[2],
                "title": p[0],
                "abstract": "",
                "source": response.url
            }
            p = Paper(**data)
            yield p
