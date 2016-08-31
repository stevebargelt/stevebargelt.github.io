

#### Azure CLI

More information: [Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-classic-cli-use-docker/)

1. Access Azure CLI utility
	Assuming you have docker locally, my favorite: `docker run -it microsoft/azure-cli`
	or
	installer: 
	https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/
2. azure login 
	you will open a browser window and ebter the code
	slick as hell


azure vm image list westus canonical

canonical  UbuntuServer               16.04.0-LTS        Linux  16.04.201608150  westus canonical:UbuntuServer:16.04.0-LTS:16.04.201608150   

azure vm docker create -e 22 -l "West US" dockerBarge2 "canonical:UbuntuServer:16.04.0-LTS:16.04.201608150 " <username> <password>

