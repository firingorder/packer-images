#!/usr/bin/env python3
# Leave the cluster in an orderly fashion when the spot instance is preempted or scheduled for maintenance
from subprocess import check_output
from socket import gethostname
from time import sleep
from json import loads
from urllib.request import Request, urlopen
from urllib.parse import urlencode

METADATA_URL = "http://169.254.169.254/metadata/scheduledevents?api-version=2017-11-01"

def get_scheduled_events():
    req = Request(METADATA_URL)
    req.add_header('Metadata', 'true')
    res = urlopen(req)
    data = loads(res.read())
    return data

def acknowledge_event(event_id):
    req = Request(METADATA_URL, urlencode({"StartRequests":[{"EventId":event_id}]}))
    req.add_header('Metadata', 'true')
    res = urlopen(req)
    data = res.read()
    return data

def handle_events(data):
    hostname = gethostname()
    for event in data['Events']:
        if hostname in event['Resources'] and event['EventType'] in ['Reboot', 'Redeploy', 'Preempt']:
            check_output('/usr/local/bin/k3s/k3s-stop.sh', shell=True)
            acknowledge_event(event['EventId'])

if __name__ == '__main__':
    while(True):
        sleep(15)
        handle_events(get_scheduled_events())