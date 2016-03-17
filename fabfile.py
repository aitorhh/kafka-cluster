from fabric.api import run, sudo
from fabric.contrib.files import sed, append
from fabric.operations import put


def zookeeper_conf(identifier, filename):
    """
    Upload the zookeeper configuration and set id

    Example of the file (zookeeper.properties):
        clientPort=2081
        dataDir=/tmp/zookeeper
        server.<id>=<ip>
        ...
        server.<id+n>=<ip+n>

    Example of myid file at <dataDir>/:
        <id>
    """
    put(filename, "/etc/kafka/zookeeper.properties", use_sudo=True)
    sudo("mkdir -p /tmp/zookeeper")
    sudo("echo %s > /tmp/zookeeper/myid" % identifier)


def kafka_conf(filename):
    """ Upload kafka configuration with all the zookeeper nodes

    Example of the file:
        broker.id=<id>
        port=9092
        zookeeper.connect=<ip>:<port>,...,<ip+n>:<port+n>
    """
    put(filename, "/etc/kafka/server.properties", use_sudo=True)

def update_hosts(hosts_file):
    """ Function to send the hosts mapping to each instance """

    with open(hosts_file, 'r') as file:
        for h in file.readlines():
            append("/etc/hosts", text=h, use_sudo=True)

def enable_supervisor_svc(name):
    """ Generic function to enable supervisor conf """
    sed(filename="/etc/supervisor/conf.d/%s.conf" % name,
        before="autostart=false",
        after="autostart=true",
        use_sudo=True)

def enable_kafka():
    """ Set autostart to the supervisor configuration file """
    enable_supervisor_svc(name="kafka")

def enable_zookeeper():
    """ Set autostart to the supervisor configuration file """
    enable_supervisor_svc(name="zookeeper")

def update_supervisor():
    """ Update supervisor configuration """
    sudo("supervisorctl reread")
    sudo("supervisorctl update")

def restart_service(svc_name):
    sudo("supervisorctl restart %s" % svc_name)


