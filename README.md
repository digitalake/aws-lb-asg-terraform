# <h1 align="center">Auto-scaling group (ASG) task</a>
### About
The Terraform code and some other code in this repo can be used to create the ASG with the Aplication Load Balancer (ALB) in AWS with all necessary components such as vpc, subnets, security groups, etc.

### Concept

In this task the EC2 with ASG + Docker solution was used.

Each of the EC2s in the ASG requires the launch template, so for creating the ami I decided to use HashiCorp Packer image creation tool.
It gives an option to define the necessary configuration for the future images and supports various plugins (in my situation, the _amazon_ plugin).

The idea was to create an ami with Docker + necessary Docker image and then exec the _docker run_ command as the _user_data_ script on launch. By navigating [here](https://github.com/digitalake/aws-lb-asg-terraform/blob/main/packer/ubuntu22.04-docker-demoapp.pkr.hcl), You can see the Packer configuration.

The _user_data_ script is defined [here](https://github.com/digitalake/aws-lb-asg-terraform/blob/main/user_data/user_data.sh) and it's a single-line script just to start the container.

The container for this task is the one was proposed - [link](https://github.com/benc-uk/nodejs-demoapp). The last 4.9.7 version for the application is used.

### Infra scheme

![undefined (1)](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/b55bd2b7-bbb0-41f1-8a20-0cf3d26f7d41)

>So above You can see the scheme for the scaled (in all 3 AZs EC2 instances)

### Load Testing

For load testing I did use the pair of tools: The [DockerCPUStress](https://github.com/containerstack/docker-cpustress) and the [Artillery](https://www.artillery.io).

The first one can be used for loading the CPU resource of the server by running the Docker container, the second one can also be used as the containerized tool and helps to perform HTTP APIs and  WebSocket testing. Artillery uses _.yml_ configurations and can also be implemented as a part of the CI/CD.



### Results: Building infrastructure

__Running _packer build_ ended with success:__

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/f39c8842-ae88-4ff4-9d76-72a088fc5973" width="500">


__So the image is accesible via Console:__


<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/3e966283-a522-4e59-9004-6d4bca3cb3d1" width="400">



__After running _terraform apply_ i wanted to see some outputs:__

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/f0a9587a-6fcf-4700-b8a2-f287d84d4ed3" width="650">


### Results: CPU Load testing

I created two pairs of CloudWatch Alarms: based on the avarage _CPUUtilization_ of the ASG EC2s and the _RequestsCountPerTarget_ of the ALB. The Alarms are triggering upscaling and downscaling.

So, for CPUUtilization Auto-scaling test such command was executed on each EC2:


```
docker run -it --name cpustress --rm containerstack/cpustress --cpu 1 --timeout 60s --metrics-brief 
```

__The CPU metric Alarm__

The Cloud watch shows that the Alarm is active:

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/e2ba9644-88e9-4693-abb6-887331c6f34f" width="270">


__The CPU graph__

On the graph we can see high CPU load:

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/18a819da-0347-4bb7-8e4a-6c47241ee066" width="600">


__The desired capacity changed (ASG activity):__

![Screenshot from 2023-09-04 13-53-33](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/301507c7-b81d-4f3f-9644-fab6d905282b)

__The new instance was launched:__

![Screenshot from 2023-09-04 13-53-47](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/2c13f850-4e90-4554-80ad-8b823cc19069)

__One more instace creation by changing desired capacity:__

![Screenshot from 2023-09-04 13-58-50](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/fa956f31-b997-49fa-99e1-9a12e2b390dd)

__After the CPU usage was decreased, the downscaling Alarm triggered the EC2 down scaling:__

3-->2

![Screenshot from 2023-09-04 13-59-38](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/361b1670-f8f0-4298-ae73-fdb65fdd0fa9)

2-->1

![Screenshot from 2023-09-04 14-01-34](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/46270bfd-e9fd-4723-8392-ece59ecfc7af)


__Shutting-down:__

3-->2

![Screenshot from 2023-09-04 13-59-17](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/f0cf8c9d-2664-4891-a258-42e5109f4a5b)

2-->1

![Screenshot from 2023-09-04 14-01-07](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/31a46b74-b43c-4ed5-b7d0-cb8f9826739c)

### Results: Request-based load testing

__Using Artillery__

For running Artillery i created the config and used another _docker run_ command:


```
docker run --rm -ti --volume ./:/opt artilleryio/artillery:2.0.0-36 run /opt/load-test.yml
```

__The output:__

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/6421a007-7676-4e5b-870d-d3a1d55afddf" width="650">


__We can also see the active Alarm on the Graph:__

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/6884daf7-feb2-4d3f-98a4-28405dfe7373" width="650">

__The Alarm also triggers changing the desired capacity:__

![Screenshot from 2023-09-04 16-09-12](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/4746ef08-890b-4406-8fad-082ff0c32d66)

__So new instance was launched:__

![Screenshot from 2023-09-04 16-09-24](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/ef949d3d-ad6b-41e2-bae0-0901e09a9b60)

__After the traffic was descreased, the downscaling alarm triggered the down scaling:__

<img src="https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/b83378ec-2ac1-4d94-8f4a-ac386cc06819" width="650">


__So the second instance was terminated:__

![Screenshot from 2023-09-04 16-18-15](https://github.com/digitalake/aws-lb-asg-terraform/assets/109740456/95885a65-1563-40c4-bf1b-a34e88113c6b)







 


