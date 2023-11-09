# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html


# useful for handling different item types with a single interface
from wan import ntf
from itemadapter import ItemAdapter
from watcher.items import Paper

import os
import json
from scrapy.exceptions import DropItem

import os
import json
from scrapy.exceptions import DropItem

class WatcherPipeline:
    def __init__(self):
        self.file_path = os.path.join(os.path.dirname(__file__), 'data.json')
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

    def process_item(self, item: Paper, spider):
        if self.id_in_data(item['id']):
            raise DropItem("Duplicate item found: %s" % item)
        else:
            self.data.append(dict(item))
            ntf(dict(item))
            return item

    def close_spider(self, spider):
        with open(self.file_path, 'w') as f:
            json.dump(self.data, f)

    def open_spider(self, spider):
        with open(self.file_path) as f:
            self.data = json.load(f)
