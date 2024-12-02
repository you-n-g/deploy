# Quick start


## Install dependencies
```bash
pip install scrapy
pip install wanot rdagent
```


## Run the spider
```bash
scrapy list
scrapy crawl nips24
scrapy crawl icml24
```

## following lpiplines

```bash
python scripts/create_pool.py
python scripts/rank_paper.py
```
