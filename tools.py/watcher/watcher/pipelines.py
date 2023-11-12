# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html

# useful for handling different item types with a single interface
from wan import ntf
from watcher.items import Paper, OpenReviewPaper

import os
import json
from scrapy.exceptions import DropItem


class BasePipeline:
    def __init__(self, fname='data.json'):
        self.file_path = os.path.join(os.path.dirname(__file__), fname)
        if not os.path.isfile(self.file_path):
            with open(self.file_path, 'w') as f:
                json.dump([], f)
        with open(self.file_path) as f:
            self.data = json.load(f)

    def id_in_data(self, id):
        for item in self.data:
            if item['id'] == id:
                return True
        return False

    def close_spider(self, spider):
        with open(self.file_path, 'w') as f:
            json.dump(self.data, f)

    def open_spider(self, spider):
        with open(self.file_path) as f:
            self.data = json.load(f)


class WatcherPipeline(BasePipeline):
    def process_item(self, item: Paper, spider):
        if isinstance(item, Paper):
            if self.id_in_data(item['id']):
                raise DropItem("Duplicate item found: %s" % item)
            else:
                self.data.append(dict(item))
                ntf(dict(item))
                return item
        return item


class OpenReviewPipeline(BasePipeline):
    def __init__(self, fname='openreview.json'):
        super().__init__(fname)

    def process_item(self, item: OpenReviewPaper, spider):
        if isinstance(item, OpenReviewPaper):
            if self.id_in_data(item['id']):
                raise DropItem("Duplicate item found: %s" % item)
            else:
                self.data.append(dict(item))
                return item
        return item
