import {runTransaction as firestoreTransaction} from 'firebase/firestore';

// Reuse existing command payload fixtures after the L1 write-set change.
// Only retired projection operations are omitted; all authoritative writes
// still go through the real client SDK and exact deployment Rules.
export async function runTransaction(db, action, options) {
  if (process.env.GROUP_SOURCE_READ !== '1') return firestoreTransaction(db, action, options);
  return firestoreTransaction(db, async tx => {
    let reads = Promise.resolve();
    return action(new Proxy(tx, {
      get(target, key) {
      // Historical fixtures use Promise.all for reads; Dart writers await each
      // read. Serialize fixture reads to match that ordering.
      if (key === 'get') return ref => {
        const result = reads.then(() => target.get(ref));
        reads = result;
        return result;
      };
      if (['set', 'update', 'delete'].includes(key)) return (ref, ...args) => {
        if (ref.path.includes('/raidListings/')) return target;
        return target[key](ref, ...args);
      };
      const value = target[key];
      return typeof value === 'function' ? value.bind(target) : value;
      },
    }));
  }, options);
}
