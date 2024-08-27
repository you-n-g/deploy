# Define here the models for your scraped items
#
# See documentation in:
# https://docs.scrapy.org/en/latest/topics/items.html

import scrapy


class WatcherItem(scrapy.Item):
    # define the fields for your item here like:
    # name = scrapy.Field()
    pass


class Paper(scrapy.Item):
    id = scrapy.Field()
    title = scrapy.Field()
    abstract = scrapy.Field()
    source = scrapy.Field()

class OpenReviewPaper(scrapy.Item):
    id = scrapy.Field()  # url
    title = scrapy.Field()
    abstract = scrapy.Field()
    keywords = scrapy.Field(required=False)
    rating = scrapy.Field(serializer=list, required=False)
    source = scrapy.Field()
    venue = scrapy.Field(required=False)
