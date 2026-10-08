"""Read-only narrow official API probes; new raw evidence for measurability audit."""
from pathlib import Path
from urllib.request import Request,urlopen
import json,datetime,hashlib,csv,io,concurrent.futures
ROOT=Path(__file__).resolve().parent
SNAPSHOT=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
PROBES={
 'oecd_business_researchers':'https://sdmx.oecd.org/public/rest/v1/data/OECD.STI.STP,DSD_MSTI@DF_MSTI,1.3/USA+DEU.A.B_RS.FTE._Z._Z?startPeriod=2021&endPeriod=2023&dimension_at_observation=AllDimensions&format=csvfile',
 'eurostat_education_labor':'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/lfsa_egaed?lang=en&freq=A&unit=THS_PER&sex=T&age=Y25-64&isced11=ED5-8&geo=DE&sinceTimePeriod=2021&untilTimePeriod=2023',
 'eurostat_rd_investment':'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nama_10_a64_p5?geo=DE&freq=A&nace_r2=TOTAL&asset10=N1171G&na_item=P51G&unit=CP_MNAC&sinceTimePeriod=2021&untilTimePeriod=2023',
 'eurostat_lfs_definitions':'https://ec.europa.eu/eurostat/cache/metadata/en/lfsa_esms.htm',
 'oecd_msti_definitions':'https://www.oecd.org/en/data/datasets/main-science-and-technology-indicators.html',
}
def fetch(item):
 name,url=item; row={'name':name,'url':url,'retrieved_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 try:
  req=Request(url,headers={'User-Agent':'Mozilla/5.0 (academic measurement feasibility audit)'})
  with urlopen(req,timeout=45) as r:
   body=r.read(); row.update(http_status=r.status,final_url=r.url,content_type=r.headers.get('Content-Type'))
  ext='csv' if name.startswith('oecd_business') else ('html' if name.endswith('definitions') else 'json')
  path=ROOT/'raw'/SNAPSHOT/f'{name}.{ext}';path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(body)
  row.update(raw_file=str(path.relative_to(ROOT)),bytes=len(body),sha256=hashlib.sha256(body).hexdigest())
  if ext=='json':
   d=json.loads(body);row.update(label=d.get('label'),updated=d.get('updated'),n_values=len(d.get('value',{})),dimensions=d.get('id'),error=d.get('error'))
  if ext=='csv':
   rr=list(csv.DictReader(io.StringIO(body.decode('utf-8-sig'))));row.update(n_rows=len(rr),columns=list(rr[0]) if rr else [],observations=[{k:r.get(k) for k in ['REF_AREA','MEASURE','UNIT_MEASURE','PRICE_BASE','TRANSFORMATION','TIME_PERIOD','OBS_VALUE','OBS_STATUS']} for r in rr])
 except Exception as e: row.update(error_type=type(e).__name__,error=str(e))
 return row
def main():
 (ROOT/'raw').mkdir(parents=True,exist_ok=True)
 out=list(concurrent.futures.ThreadPoolExecutor(5).map(fetch,PROBES.items()))
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
 (ROOT/f'query_log_{stamp}.json').write_text(json.dumps(out,indent=2)+'\n')
 print(json.dumps(out,indent=2))
if __name__=='__main__':main()
