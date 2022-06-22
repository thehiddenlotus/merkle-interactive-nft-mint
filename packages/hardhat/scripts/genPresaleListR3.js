// const whitelistAddresses = {
//     "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": "xxxxProoof1",
//     "0x70997970c51812dc3a010c7d01b50e0d17dc79c8": "xxxProof2"
// }

// console.log(whitelistAddresses)
// console.log(whitelistAddresses["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"])

const fs = require("fs");
const parse = require("csv-parse");
const csv = require("csv-parser");
const ethers = require("ethers");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");

const inputFilePath = "./presaleList.csv";

let rawWhitelistAddressArray;
let cleanWhitelistArrayOfObjects = [];
let finalMap = {};
let leafNodes, merkleTree, rootHash;

async function readFile() {
  const temp = fs.readFileSync(inputFilePath, "utf8");
  rawWhitelistAddressArray = temp.split(/\r?\n/);
}

async function processArray() {
  for (const element of rawWhitelistAddressArray) {
    // console.log(element);
    finalMap[element] = "temp";
  }
}

function createArrayOfObjects() {
  for (const element of rawWhitelistAddressArray) {
    let temp = {};
    try {
      temp.address = ethers.utils.getAddress(element.toString().toLowerCase());
      temp.amount = 1; //! AMOUNT HERE
      cleanWhitelistArrayOfObjects.push(temp);
    } catch (error) {
      // console.log(error)
      // console.log(typeof (element))
      console.log(element.toString(), "is not a valid address");
    }
    //! IMPORTANT DUPE THE FIRST ADDRESS IN THE FILE, just something weird with reading in data that fucks up first row
    // temp.address = element.toString()
    // temp.amount = 3
    // console.log(temp)
  }
}

function createMerkleTreeGetRoot() {
  leafNodes = cleanWhitelistArrayOfObjects.map((x) =>
    ethers.utils.solidityKeccak256(
      ["address", "uint256"],
      [x.address, x.amount]
    )
  );
  merkleTree = new MerkleTree(leafNodes, keccak256, { sort: true });
  rootHash = merkleTree.getRoot();
}

function getProofsPopulateArrayofObjects() {
  for (let i = 0; i < cleanWhitelistArrayOfObjects.length; i++) {
    const leaf = leafNodes[i];
    const hexProof = merkleTree.getHexProof(leaf);
    finalMap[cleanWhitelistArrayOfObjects[i].address] = hexProof;
    // if (i == 24) {
    //     console.log('leaf', leaf)
    //     console.log('hexProof', hexProof)
    // }
  }
}

async function main() {
  await readFile();
  // console.log('rawWhitelistAddressArray:', rawWhitelistAddressArray)
  // console.log(rawWhitelistAddressArray[26])

  createArrayOfObjects();
  // console.log('cleanWhitelistArrayOfObjects:', cleanWhitelistArrayOfObjects)
  // console.log(cleanWhitelistArrayOfObjects[24]);

  createMerkleTreeGetRoot();
  getProofsPopulateArrayofObjects();
  // console.log('finalMap:', finalMap)

  console.log("rootHash:", rootHash.toString());
  const rootHexHash = merkleTree.getHexRoot();
  console.log("rootHexHash:", rootHexHash);

  const manualCheckAddress = ethers.utils.getAddress(
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" //! Test address will be output with proof
  );

  console.log(
    "finalMap[" + manualCheckAddress + "]",
    finalMap[manualCheckAddress]
  );

  // console.log('leafNodes[24]:', leafNodes[24])
  // console.log(finalMap);

  saveToFile();
}

function saveToFile() {
  const fs = require("fs");
  const path = require("path");

  fs.writeFileSync(
    path.resolve(__dirname, "finalPresaleMap.json"), //! FILENAME
    JSON.stringify(finalMap)
  );
}

main();
/*
rootHexHash: 
0x2d7bce87601a54a1b37cf09161ebdc209b8d06d4c919c6aca54de7eab14e78c2

"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266":
[
  "0x67ad9c319b6c467330e8a31887fc91be08aba4e1004dd7ca76bfca3ab260b1ff",
  "0x22e7e34d8d33a0a39ca89976779487aa3a7db6ba5e9de41404234d581a487731",
  "0x56af4daf1a48aececb027f375acca1dd68da83e08169b29d082b133783fb5c25",
  "0x21a7ed3984b0686c0b7d5d365fc208980b52cb36a2990575021d181b0e450f33",
  "0x2ea90eb71d2a82855acc20a2c0cefff262f0494ad8a8f61d2c245de2d34a26d4",
  "0xdfe9aeb17c8ce6a3d24d56643c7452ade70419f64d8d129e34f850d3fa7c99ec",
  "0x77edf8439296182df9f3638156e49a7457d786db7e8bfbee6fa4732d5c84f00a",
  "0x51370f0c1de0e7f9df020de71b7d213aafd88ea15878169f3d6dd159205d176d",
  "0xdfb476d1eb45fe7f879a18671b0a90af67c5d13bc21d837ab25b5122cfd0d1e6",
  "0x0d90e9edf1dfc6446c340ef690c6b8b8826fbcaaf2fe855e2803c5e1fc3bf414",
  "0xd6e40fc10adaf0c4a01968c90873501670fe354732fe6b81812247a83bd7543d",
  "0x8a04e4e3944f6ad38ca826d273ed219c0e80896a200a6110e34219a141091536",
  "0x8a754ed86e0a8cfdf0153b5bd11143c6250c953a1ea408bbe29875d2033b08ea"
]
["0x67ad9c319b6c467330e8a31887fc91be08aba4e1004dd7ca76bfca3ab260b1ff","0x22e7e34d8d33a0a39ca89976779487aa3a7db6ba5e9de41404234d581a487731","0x56af4daf1a48aececb027f375acca1dd68da83e08169b29d082b133783fb5c25","0x21a7ed3984b0686c0b7d5d365fc208980b52cb36a2990575021d181b0e450f33","0x2ea90eb71d2a82855acc20a2c0cefff262f0494ad8a8f61d2c245de2d34a26d4","0xdfe9aeb17c8ce6a3d24d56643c7452ade70419f64d8d129e34f850d3fa7c99ec","0x77edf8439296182df9f3638156e49a7457d786db7e8bfbee6fa4732d5c84f00a","0x51370f0c1de0e7f9df020de71b7d213aafd88ea15878169f3d6dd159205d176d","0xdfb476d1eb45fe7f879a18671b0a90af67c5d13bc21d837ab25b5122cfd0d1e6","0x0d90e9edf1dfc6446c340ef690c6b8b8826fbcaaf2fe855e2803c5e1fc3bf414","0xd6e40fc10adaf0c4a01968c90873501670fe354732fe6b81812247a83bd7543d","0x8a04e4e3944f6ad38ca826d273ed219c0e80896a200a6110e34219a141091536","0x8a754ed86e0a8cfdf0153b5bd11143c6250c953a1ea408bbe29875d2033b08ea"]

*/
