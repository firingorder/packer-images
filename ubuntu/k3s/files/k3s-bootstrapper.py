#!/usr/bin/env python3
from bottle import get, run, abort
from subprocess import check_output
from socket import gethostname
from signal import signal, setitimer, ITIMER_REAL, SIGALRM
from sys import stderr

def cleanup(signum, frame):
    if signum in [9, 15]:
        stderr.write(f"Exiting on signal {signum}\n")
        exit(0)
    try:
        nodes = check_output('kubectl get nodes', shell=True).strip().decode("utf-8")
        untagged = map(lambda x: x.split()[0], filter(lambda x: '<none>' in x, nodes.split('\n')))
        down = map(lambda x: x.split()[0], filter(lambda x: 'NotReady' in x, nodes.split('\n')))
        for node in untagged:
            check_output(f"kubectl label node {node} kubernetes.io/role=worker", shell=True)
        for node in down:
            check_output(f"kubectl cordon {node}", shell=True)
            check_output(f"kubectl delete node {node}", shell=True)
    except Exception as e:
        stderr.write(f"{e}\n")
        pass
    
@get("/join/<hostname>")
def token(hostname):
    try:
        check_output(f"kubectl uncordon {hostname}", shell=True)
    except:
        pass
    return check_output("cat /var/lib/rancher/k3s/server/token", shell=True).strip()

@get("/drain/<hostname>")
def drain(hostname):
    try:
        check_output(f"kubectl drain {hostname} --ignore-daemonsets --delete-local-data", shell=True)
        return check_output(f"kubectl cordon {hostname}", shell=True).strip()
    except:
        abort(404, "node not found")

if gethostname() == 'leader':
    signal(SIGALRM, cleanup)
    setitimer(ITIMER_REAL, 60, 10)
    run(port=1337,host='0.0.0.0')