/**
 * 测试 fixture：固定 ES256 PEM。仅用于单元/集成测试，与生产凭证无关。
 * 生成命令：
 *   node -e "const {generateKeyPairSync}=require('crypto');
 *            const {privateKey}=generateKeyPairSync('ec',{namedCurve:'P-256'});
 *            console.log(privateKey.export({type:'pkcs8',format:'pem'}))"
 */
export const TEST_APNS_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQguMmPwmQ2b/8HwMv9
LabK04u/TAvT/WFZsXZhtlTq9k6hRANCAAT8UrjuzrahtlKSM04YwI8zJeotHL6a
Hl941PaoSYkzN6MC/M2utDHtOETntpEYRw5gRmPruQfY1QhxLzbeFN2M
-----END PRIVATE KEY-----
`;
