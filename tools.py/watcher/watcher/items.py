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
