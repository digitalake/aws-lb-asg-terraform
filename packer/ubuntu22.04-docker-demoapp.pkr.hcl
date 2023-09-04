packer {
  required_plugins {
    amazon = {
      version = ">= v1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "asg-template" {
  ami_name      = "ubuntu22.04-docker-demoapp"
  instance_type = "t2.micro"
  source_ami = "ami-053b0d53c279acc90"
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.asg-template"]

  provisioner "shell" {
    inline = [ <<EOF
      sudo apt-get update
      sudo apt-get install ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      sudo apt-get -y install docker-ce docker-ce-cli containerd.io
      sudo usermod -a -G docker $USER
      sudo docker pull ghcr.io/benc-uk/nodejs-demoapp:4.9.7
      EOF
    ]
  }
}
