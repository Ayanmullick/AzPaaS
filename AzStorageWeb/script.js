import {BlobServiceClient} from 'https://cdn.jsdelivr.net/npm/@azure/storage-blob@12.26.0/+esm'
import {ShareServiceClient} from 'https://cdn.jsdelivr.net/npm/@azure/storage-file-share@12.26.0/+esm'

const  uploadButton = document.getElementById("upload-file");
let servicesRadio = document.querySelectorAll("[name='service']");
const storageFileInput = document.getElementById("storage-file");
const shareFileInput = document.getElementById("share-file");


servicesRadio.forEach(function (radio) {
    radio.addEventListener('change', function (event) {
        let target = event.target;
        let fileBlockContainer = document.getElementById('file-block-container');
        let storageBlockContainer = document.getElementById('storage-block-container');
        if (target.id === "file-service") {
            fileBlockContainer.style.display = 'block';
            storageBlockContainer.style.display = 'none';
        } else {
            fileBlockContainer.style.display = 'none';
            storageBlockContainer.style.display = 'block';
        }
    });
});

uploadButton.addEventListener('click',function(e){
    const button = e.target;
    const storageFile = storageFileInput.files[0];
    const shareFile = shareFileInput.files[0];
    const checkedService = document.querySelector("[name='service']:checked").value;
    const [accountName,containerName,sasToken] = getServiceInputValues(checkedService);
    let uploadPromise;

    if(storageFile || shareFile) {
        button.disabled = true;
        const accountUrl = generateAccountUrl({
            accountName,
            containerName,
            sasToken,
            'serviceType':checkedService
        });
        const serviceClient = serviceFactory(checkedService,accountUrl);
        if(checkedService === 'blob') {
            uploadPromise = uploadBlobFromBrowser(
                serviceClient.getContainerClient(containerName),
                storageFile
            )
        } else if(checkedService === 'file') {
            uploadPromise = uploadSharedFileFromBrowser(
                serviceClient.getShareClient(containerName),
                shareFile
            )
        } else {
            return;
        }

        uploadPromise.then(r => {
                button.disabled = false;
                showMessages('success');
            })
            .catch(err => {
                console.log(err);
                button.disabled = false;
                showMessages('error',err);
            });
    }

})

function getServiceInputValues(checkedService) {
    if(checkedService === 'blob') {

        return [
            document.getElementById('storage-account').value,
            document.getElementById('storage-container-name').value,
            document.getElementById('storage-access-key').value,
        ];
    }

    return [
        document.getElementById('file-account').value,
        document.getElementById('file-share-name').value,
        document.getElementById('file-access-key').value,
    ];

}

function serviceFactory(serviceType,accountUrl) {
    switch (serviceType) {
        case "blob": return  new BlobServiceClient(accountUrl);
        case "file": return  new ShareServiceClient(accountUrl);
        case 'default': return  null;
    }
}

function generateAccountUrl(azureInfos) {
    return `https://${azureInfos['accountName']}.${azureInfos['serviceType']}.core.windows.net?${azureInfos['sasToken']}`;
}

async function uploadBlobFromBrowser(containerClient, file){
    const blockBlobClient = containerClient.getBlockBlobClient(file.name);
    const blockSize = 10 * 1024 * 1024; // 10MB
    const fileSize = file.size;
    const blockCount = Math.ceil(fileSize / blockSize);
    const blockIds = [];
    let bytesUploaded = 0;
    let percentComplete = 0;
    for (let i = 0; i < blockCount; i++) {
        const start = i * blockSize;
        const end = Math.min(start + blockSize, fileSize);
        const chunk = file.slice(start, end);
        const chunkSize = end - start;
        const blockId = btoa("block-" + i.toString().padStart(6, "0"));
        blockIds.push(blockId);
        await blockBlobClient.stageBlock(blockId, chunk, chunkSize).then((res) => {
            bytesUploaded += blockSize;
            percentComplete = ((parseFloat(bytesUploaded) / parseFloat(fileSize)) * 100).toFixed(2);
            document.getElementById('progress').value = percentComplete;
            document.getElementById('progress-percent').innerText = percentComplete + '%';
        });
    }
    return await blockBlobClient.commitBlockList(blockIds);
}

async function uploadSharedFileFromBrowser(serviceClient, file){
    const fileClient = serviceClient.rootDirectoryClient.getFileClient(file.name);
    // await fileClient.create(fileSize); fileClient.uploadRange
    return await fileClient.uploadData(file);

}

function showMessages(type,error = null) {
    if(type === "success") {
        document.querySelector('.msg-success').classList.remove('d-none');
        document.querySelector('.msg-error').classList.add('d-none');
    } else if(type === "error") {
        document.querySelector('.msg-success').classList.add('d-none');
        document.querySelector('.msg-error').classList.remove('d-none');
        document.querySelector('.msg-error').innerText = error
    }
}
