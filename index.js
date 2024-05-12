import Docker from 'dockerode'
import cron from 'node-cron';

const CONTAINERS = process.env.AUTOSTART_CONTAINERS || '';
// const CRON_INTERVAL = process.env.AUTOSTART_CRON_INTERVAL || '*/15 * * * * *' // every 15 sec
const CRON_INTERVAL = process.env.AUTOSTART_CRON_INTERVAL || '*/5 * * * *' // every 5 min

const containtersList = CONTAINERS.split(',').filter(Boolean)

const docker = new Docker({
  socketPath: '/var/run/docker.sock',
  timeout: 10000,
});


const findContainer = async (name) => {
  const containers = (await docker.listContainers({ all: true })) ?? [];

  return containers.find((container) => container.Names?.[0] === `/${name}`);
};

const isContainerRunning = async (name) => {
  const existingContainer = await findContainer(name);
  return existingContainer && existingContainer?.State === 'running';
};


const startContainer = async (name) => {
  if (await isContainerRunning(name)) {
    return;
  }

  let existingContainer = await findContainer(name);

  if (!existingContainer) {
    console.log(`startContainer(${name}) not found =(`);
    return;
  }

  try {
    console.log(`startContainer(${name}) starting...`);
    const container = docker.getContainer(existingContainer.Id);
  
    await container.start();

    console.log(`startContainer(${name}) done`);
  } catch (error) {
    console.log(`startContainer(${name}) error`, error);
  }
};

const srartContainers = async () => {
  for (let containerName of containtersList) {
    try {
      await startContainer(containerName);
    } catch {}
  }
}

console.log(containtersList)
srartContainers();

cron.schedule(CRON_INTERVAL, async () => {
  // console.log('cron started')
  await srartContainers();
  // console.log('cron finished')
});