### install k8s


### Usage

* create a hosts file to override the k8s node defualt hosts file

* for example
`vim ./hosts`
```
# k8s nodes
192.168.18.6 dk8scp1
192.168.18.7 dk8snodecicd1
192.168.18.8 dk8snodeap1
192.168.18.9 dk8snodedb1

```

* install k8s cp node

`./install-k8s.sh ./hosts cp`

* add k8s node
`./install-k8s.sh ./hosts node`


* install helm char

`./install-helm.sh`
